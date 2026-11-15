<!-- archmd:start v0.3.6 -->
<!-- Section layout inspired by https://architecture.md/ -->
<!--
出典: ARCHITECTURE.md Template by timajwilliams (https://github.com/timajwilliams/architecture)。
archmd により節・見出し・説明を再構成し、ID マーカーと更新ルールを追加。
SPDX-License-Identifier: Apache-2.0
ライセンス全文: https://www.apache.org/licenses/LICENSE-2.0.txt
再配布時はこの表示を保持し、Apache-2.0 全文と archmd notices の出典表示を同梱する。
この表示はテンプレート・ルールに適用され、記載対象プロジェクトのライセンスは指定しない。
-->
- Read ARCHITECTURE.md first before working; it summarizes this repository's architecture.
- When your change affects the project structure, components, data stores, external integrations, or deployment, update ARCHITECTURE.md in the same task.
- Update only the affected sections; do not rewrite the whole file.
- Never delete or edit the `<!-- arch:... -->` marker lines. They list every section this document can have, in order.
- If a section has nothing to document, remove its heading and body but keep its marker line. To fill an empty section, write an H2 heading directly under its marker, using the heading text in the marker.
- Be concise. For data stores, list table or collection names only. Put long setup instructions in CONTRIBUTING.md, and remove hint comments once filled in.
- Only document what the repository evidences. Do not invent systems, services, data stores, or integrations; when something is unclear, write "Not confirmed from the repository."
- Before finishing, verify that every component, service, data store, and integration you named actually exists in the repository, and that each major source directory is covered.
- The document should answer: if I need to change X, where do I look and what does it affect? Prefer durable structure over volatile implementation details.
- If `archmd` is installed, run `archmd check` after editing and resolve every ERROR. Without it, keep every ID marker and keep the required sections: project-structure, high-level-diagram, core-components, project-identification.
- If `.architecture/` exists (this requires `archmd`), ARCHITECTURE.md is generated: edit the files in `.architecture/` and then run `archmd build`; never edit ARCHITECTURE.md directly.
ドキュメントとコメントは基本日本語で書く。ARCHITECTURE.md の見出し(H2)も日本語に翻訳してよい。ただし `<!-- arch:... -->` のIDマーカーは絶対に変更しない。
<!-- archmd:end -->
