# 大学樹木マップ

Garmin GPSMAPで取得した樹木の位置と樹種名を、Google Sheetsで管理し、GitHub Pagesで公開する静的Web地図です。

## 運用の流れ

1. Google Sheetsに `trees` と `species` の2シートを作ります。
2. `trees` に樹木を1行ずつ追加します。
3. 各シートをCSVとして「ウェブに公開」します。
4. GitHub repository secrets にCSV URLを登録します。
5. GitHub ActionsがCSVを検証し、`data/public/trees.csv` と `data/public/trees.geojson` を生成してGitHub Pagesへ公開します。

## データを追加・更新する方法

通常の更新はGoogle Sheetsだけで行います。GitHub上のCSVやGeoJSONは生成物なので、直接編集しません。

1. Garmin GPSMAPで取得した緯度・経度をWGS84の10進度にそろえます。
2. Google Sheetsの `trees` シートに新しい行を追加します。
3. `tree_id`, `lat`, `lon`, `species_jp`, `survey_date`, `publish` を必ず入力します。
4. まだ確認中の個体は `publish` を `FALSE` にしておきます。
5. 公開してよい状態になったら `publish` を `TRUE` にします。
6. GitHub Actionsの `Publish tree map` を手動実行するか、定期実行を待ちます。
7. 公開サイト、CSV、GeoJSONに反映されたことを確認します。

手動実行する場合は、GitHubの `Actions` タブで `Publish tree map` を開き、`Run workflow` を押します。

## 既存データを修正する方法

- 樹種名、学名、調査日、公開メモを直す場合は、Google Sheetsの該当行を編集します。
- 座標を修正する場合は、`lat` と `lon` をWGS84の10進度で上書きします。
- 一時的に非公開にしたい場合は、行を削除せず `publish` を `FALSE` にします。
- 完全に削除したい場合だけ、Google Sheetsから行を削除します。

`tree_id` は公開済みURLやGeoJSON利用者が参照する可能性があるため、原則として変更しません。

## 更新時にビルドが失敗した場合

GitHub Actionsが失敗した場合は、まず `Actions > Publish tree map` のログを確認します。よくある原因は以下です。

- `tree_id` が重複している。
- `lat` / `lon` に数値以外の値が入っている。
- `species_jp` が空欄になっている。
- `survey_date` が `YYYY-MM-DD` ではない。
- キャンパス範囲チェックを設定している場合に、座標が範囲外になっている。

修正後に `Run workflow` で再実行してください。

## `trees` シート

必須列は以下です。列名は完全一致にしてください。

| 列名 | 内容 |
| --- | --- |
| `tree_id` | 個体ID。公開行では一意にします。例: `T-0001` |
| `lat` | WGS84の緯度。10進度。 |
| `lon` | WGS84の経度。10進度。 |
| `species_jp` | 和名。 |
| `scientific_name` | 学名。空欄の場合は `species` シートから補完します。 |
| `survey_date` | 調査日。`YYYY-MM-DD`。 |
| `observer` | 記録者。 |
| `accuracy_m` | Garmin GPSMAPの測位精度メモ。メートル。 |
| `publish` | 公開する行は `TRUE`。未確認行は `FALSE`。 |
| `note_public` | 公開してよいメモ。 |

## `species` シート

推奨列は以下です。`species_jp` 以外は空欄でも構いません。

| 列名 | 内容 |
| --- | --- |
| `species_jp` | 和名。`trees$species_jp` と対応します。 |
| `scientific_name` | 学名。 |
| `family_jp` | 科名。 |
| `marker_color` | 地図マーカー色。`#RRGGBB`。 |
| `description` | 種のメモ。将来拡張用。 |

## GitHub 設定

Repository secrets:

- `TREES_CSV_URL`: Google Sheetsの `trees` シートをCSV公開したURL。
- `SPECIES_CSV_URL`: Google Sheetsの `species` シートをCSV公開したURL。

Repository variables:

- `CAMPUS_MIN_LAT`
- `CAMPUS_MAX_LAT`
- `CAMPUS_MIN_LON`
- `CAMPUS_MAX_LON`

キャンパス範囲を設定すると、範囲外の公開座標があった場合にビルドを失敗させます。未設定の場合は、キャンパス範囲チェックだけをスキップします。

GitHub Pagesは `Settings > Pages > Source: GitHub Actions` に設定してください。

## ローカル確認

```powershell
& "C:\Program Files\R\R-4.5.3\bin\Rscript.exe" --vanilla tests/test-validation.R
& "C:\Program Files\R\R-4.5.3\bin\Rscript.exe" --vanilla scripts/build_data.R
& "C:\Program Files\R\R-4.5.3\bin\Rscript.exe" --vanilla scripts/check_generated_outputs.R
quarto render
```

`TREES_CSV_URL` と `SPECIES_CSV_URL` が未設定の場合は、`data/source/` のサンプルCSVを使います。

## 公開データ

- `data/public/trees.csv`
- `data/public/trees.geojson`

これらは手で編集せず、`scripts/build_data.R` で生成します。
