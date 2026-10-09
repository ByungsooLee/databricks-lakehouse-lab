# Day 1 — Iceberg Foundations

## 実験環境

- Platform: Databricks Free Edition
- Catalog / schema: `workspace.iceberg_lab` (Unity Catalog)
- Table: `workspace.iceberg_lab.orders_iceberg`
- Table format: Apache Iceberg（`DESCRIBE DETAIL` で `format = iceberg` を確認）
- Execution engine: Photon

この記録は実験者から提供された実行結果に基づきます。スクリーンショットや実行ログは含めておらず、未確認の結果は追加していません。

## Experiment 1 — Iceberg テーブルの作成

### Objective

Unity Catalog 上に Iceberg テーブルを作成し、テーブル形式を確認する。

### Hypothesis

`USING ICEBERG` で作成したテーブルの詳細情報に Iceberg 形式が表示される。

### Procedure

`sql/day01_iceberg_foundations.sql` の Schema 作成、`CREATE TABLE ... USING ICEBERG`、`DESCRIBE DETAIL` を順に実行。

列は `order_id BIGINT`, `customer_id BIGINT`, `order_date DATE`, `amount DECIMAL(10,2)`, `status STRING`。

### Result

`DESCRIBE DETAIL` の `format` が `iceberg` であることを確認した。

### Technical Explanation

`USING ICEBERG` はテーブルの論理形式を指定する。Iceberg はテーブル状態とスナップショットをメタデータで管理し、データファイルには Parquet などの形式を使用できる。テーブル形式と個々のデータファイル形式は別の層である。

### Limitations

この確認だけでは、実際に使われたデータファイルの一覧、Snapshot の構造、Manifest の内容、他エンジンとの互換性は判断できない。

### Next Steps

Day 2 で Snapshot、Manifest、メタデータファイルの関係と観測方法を調べる。

## Experiment 2 — 10,000 件の書き込み

### Objective

Spark SQL `range(10000)` から Iceberg テーブルへデータを書き込み、件数と状態別件数を確かめる。

### Hypothesis

10,000 行が書き込まれ、`id % 10 = 0` の1,000行が `cancelled`、残り9,000行が `paid` になる。

### Procedure

`sql/day01_iceberg_foundations.sql` の INSERT と集計クエリを実行。`order_id = id`、`customer_id = id % 1000`、`order_date = DATE_ADD(DATE '2026-10-01', CAST(id % 7 AS INT))`、`amount = CAST(100 + id % 500 AS DECIMAL(10,2))` とした。

### Result

総件数 10,000 件、`paid` 9,000 件、`cancelled` 1,000 件を確認した。

### Technical Explanation

`range(10000)` は0から9,999までのIDを生成する。10個ごとに1件がキャンセル扱いとなるため、均等な剰余分布では10,000件中1,000件が該当する。

### Limitations

この合成データは性能や実運用の分布を代表しない。複数ファイルの生成状況、圧縮率、書き込み性能などは計測していない。

### Next Steps

DELETE 後のデータファイルやメタデータの変化を Day 3 で調査する。

## Experiment 3 — DELETE と Time Travel

### Objective

Iceberg テーブルから条件一致行を削除し、過去バージョンのデータを参照できるか確認する。

### Hypothesis

DELETE 後の現在データは9,000件となり、書き込み後に記録された Version 1 では10,000件を参照できる。削除を再実行すれば該当行はなく、影響行数は0になる。

### Procedure

`status = 'cancelled'` を条件に DELETE を実行し、現在の件数と `VERSION AS OF 1` の件数を比較。`DESCRIBE HISTORY` で履歴を確認し、同じ DELETE も再実行した。

### Result

- DELETE 後の現在の件数：9,000 件
- `VERSION AS OF 1` の件数：10,000 件
- DELETE 再実行時の影響行数：0 件
- 履歴：Version 0 `CREATE TABLE`、1 `WRITE`、2 `DELETE`、3 `DELETE`

### Technical Explanation

Time Travel はテーブル履歴上の過去状態をクエリする機能で、削除前の状態を参照できた。Databricks の履歴 Version と Apache Iceberg の Snapshot ID は異なる識別子として扱う必要がある。履歴が参照可能な期間は保持設定やメンテナンスなどに依存し得るため、過去データが永久に保持されるとは言えない。

### Limitations

この実験では、削除方式、削除ファイルの物理的な変化、保持期限、Snapshot IDとの対応を確認していない。件数の観測は、それだけでファイルスキップや物理削除の方式を示さない。

### Next Steps

Day 3 で DELETE 方式とデータファイル・メタデータの変化を調べ、Time Travel の保持条件も環境に沿って記録する。

## Experiment 4 — Spark の実行計画

### Objective

日付条件と集計を含むクエリの物理計画を確認し、Photon、読み取り列、スキャン段階のフィルタを観察する。

### Hypothesis

Photon がクエリをサポートし、集計に必要な列のみを読み取り、日付条件をスキャン段階に渡す。

### Procedure

次の集計クエリに `EXPLAIN FORMATTED` を実行した。

```sql
SELECT customer_id, COUNT(*) AS order_count, SUM(amount) AS total_amount
FROM workspace.iceberg_lab.orders_iceberg
WHERE order_date >= DATE '2026-10-04'
GROUP BY customer_id;
```

### Result

提供された Physical Plan で以下を確認した。

- `The query is fully supported by Photon.` と表示。
- `AdaptiveSparkPlan`、`PhotonResultStage`、`PhotonColumnarToRow`、`PhotonGroupingAgg`、`PhotonProject`、`PhotonScan parquet` があった。
- `ReadSchema` は `customer_id`、`order_date`、`amount` の3列で、Column Pruning と整合する。
- `order_date >= DATE '2026-10-04'` が `DictionaryFilters` と `RequiredDataFilters` に含まれていた。
- 初期計画には明示的な `Exchange` ノードがなく、`AdaptiveSparkPlan` は `isFinalPlan=false` だった。
- `Optimizer Statistics` は `full = orders_iceberg`。
- Location に `PreparedDeltaFileIndex` の表示があった。

### Technical Explanation

集計に必要な3列だけを `ReadSchema` に含める計画は Column Pruning と整合する。日付条件がフィルタ欄に現れることはスキャン段階へのフィルタ適用を示す。一方、それだけでは Iceberg Manifest Pruning が行われたことや、データファイルが実際にスキップされたことまでは立証しない。

`PhotonScan parquet` は Parquet データファイルの読み取りを示す表示であり、テーブル形式そのものが Parquet という意味ではない。テーブル形式は別途 `DESCRIBE DETAIL` で Iceberg と確認している。`PreparedDeltaFileIndex` という内部表示だけから Delta 形式と判断することもできない。

### Limitations

`isFinalPlan=false` の初期 Adaptive Query Execution 計画であり、最終実行計画ではない。初期計画に `Exchange` がないことだけで、実行時に Shuffle がなかったとは言えない。実測時間、実際に読み取ったファイル数、Manifest Pruning、最終計画は確認していない。

### Next Steps

Day 4 で最終計画と実行メトリクスを含む条件付き比較を行い、Partition Pruning、Manifest/file pruning、Spark の Column Pruning を区別して記録する。

## English interview summary

> I created an Apache Iceberg table in Databricks and tested inserts, deletes, and time travel. I also examined the Spark execution plan and confirmed that Photon applied column pruning and scan-level filters.

「scan-level filters」は計画上で観測した内容を表す。実際の Manifest Pruning やファイルスキップまで確認したという意味ではない。
