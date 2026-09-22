`TSCharacters.txt` and `TSPhrases.txt` are the Traditional→Simplified
character- and phrase-level conversion tables from the
[OpenCC](https://github.com/BYVoid/OpenCC) project, redistributed under the
Apache License 2.0. They are used at build time only, by `xlsx2json`, to
convert the "Mainland Chinese" column of `Multilingual_Vocabulary_1100.xlsx`
(PRD §6.2.1). They are not bundled into the shipping app.
