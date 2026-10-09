# Databricks × Apache Iceberg 学習ラボ

Apache Iceberg、Databricks、Apache Spark の技術検証を継続的に記録する個人ポートフォリオです。各テーマで Iceberg との関係を明確にし、再現用 SQL、観測した事実、検証の限界を残します。記載内容は個人の学習環境に基づき、Databricks の実装や機能がすべての Iceberg 環境で共通することを示すものではありません。

## 学習の進め方

- `sql/` のスクリプトで実験を再現します。
- `docs/` に Objective、Hypothesis、Procedure、Result、Technical Explanation、Limitations、Next Steps を記録します。
- 観測事実と解釈を区別し、実行していない検証の数値や結果は記載しません。
- Databricks の履歴 Version と Iceberg Snapshot ID、テーブル形式とデータファイル形式など、似た概念を区別します。

## 検証一覧

| Day | テーマ | 状態 | レポート | 再現 SQL |
|---|---|---|---|---|
| 1 | Iceberg 基礎、INSERT / DELETE、Time Travel、Spark 実行計画 | 完了 | [Day 1 レポート](docs/day01_iceberg_foundations.md) | [Day 1 SQL](sql/day01_iceberg_foundations.sql) |
| 2 | Iceberg Snapshot / Manifest / Metadata | 暫定計画 | — | — |
| 3 | DELETE 方式とデータファイルの変化 | 暫定計画 | — | — |
| 4 | Partition Pruning と Spark 性能検証 | 暫定計画 | — | — |
| 5 | MERGE / CDC / SCD Type 2 | 暫定計画 | — | — |
| 6 | Iceberg と Snowflake・BigQuery の相互運用性 | 暫定計画 | — | — |

## 学習ロードマップ

以下は今後の候補であり、結果はまだ検証していません。

1. **Day 1 — Iceberg Foundations**：テーブル作成、10,000 行の書き込み、DELETE、Time Travel、Spark 実行計画。
2. **Day 2 — Snapshot / Manifest / Metadata**：Iceberg メタデータ階層と Snapshot の内容を調査。
3. **Day 3 — DELETE とデータファイル**：削除方式や実行後のファイル・メタデータ変化を観測。
4. **Day 4 — Partition Pruning と性能**：パーティション設計、ファイル選択、Spark 実行計画や測定条件を比較。
5. **Day 5 — MERGE / CDC / SCD Type 2**：更新パターンと Iceberg テーブル上の変更管理を検証。
6. **Day 6 — 相互運用性**：Iceberg テーブルを Snowflake、BigQuery から扱う際の対応範囲と制約を調査。

## 環境

Day 1 は Databricks Free Edition、Unity Catalog の `workspace.iceberg_lab`、Apache Iceberg テーブル、Photon 実行エンジンで実施しました。各サービスの対応状況や仕様は変更される可能性があるため、将来の実験では実行環境と時点も記録します。
