# Bundled fonts

The interface uses **Roboto Flex → Noto Sans SC → Roboto → system fallback**. System fallback is provided by Flutter after the bundled families. Application icons use **Material Symbols Rounded**, with outlined controls and filled answer markers.

PDF preview and export share **Noto Sans SC → Roboto Flex**. PDF text uses static regular (400) and bold (700) instances because its TrueType embedding path does not apply variable-font axes. This also avoids Noto Sans SC's upstream default weight of 100. A custom TTF takes precedence while keeping the built-in fallbacks.

## Pinned upstream sources

- [Roboto Flex](https://github.com/google/fonts/tree/e44c4b011a820c2cbe2fd2cfa8052037d7edb571/ofl/robotoflex): unmodified variable font; SIL OFL 1.1 in `roboto-flex-license.txt`.
- [Noto Sans SC](https://github.com/google/fonts/tree/e44c4b011a820c2cbe2fd2cfa8052037d7edb571/ofl/notosanssc): unmodified variable font; SIL OFL 1.1 in `noto-sans-sc-license.txt`.
- [Material Symbols Rounded](https://github.com/google/material-design-icons/tree/27e9ef1dbeedc13d682fece4a58e1eda4cb0961a/variablefont): unmodified variable font and codepoint table; Apache 2.0 in `material-symbols-license.txt`.
- The existing static Roboto regular/bold files are retained as UI fallback with `roboto_license.txt` (Apache 2.0).

## PDF instances

Generated with fontTools 4.65.0. For each source, pin every axis to its upstream default and set `wght` to 400 or 700 using `fontTools.varLib.instancer.instantiateVariableFont`.

For Noto Sans SC, use `updateFontNames=True`. Roboto Flex lacks STAT entries for some default parametric axes, so instantiate without that flag and set name IDs 1/16 to `Roboto Flex`, 2/17 to `Regular` or `Bold`, 4 to the family plus style, and 6 to `RobotoFlex-Regular` or `RobotoFlex-Bold`. Preserve copyright and license records. The generated files in `pdf/` are checked in; normal Flutter builds do not need fontTools or Python.

## SHA-256

| Asset | SHA-256 |
| --- | --- |
| `material-symbols-rounded.ttf` | `7f3a16d9aa1b6f367eadc1614ad27308ae2c0e91e617e2069f122afd9f0c3c58` |
| `noto-sans-sc.ttf` | `a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da` |
| `pdf/noto-sans-sc-bold.ttf` | `73dbc022af1a6b60148352b28e7d1b4634fc3d233fea350ce4a0ab624d6dc8f9` |
| `pdf/noto-sans-sc-regular.ttf` | `c6a1348a1dfee80ea4f1c0c9d170ed51abdb90ce6cae73bb68014312436b01bc` |
| `pdf/roboto-flex-bold.ttf` | `68c6d0b8238e3a4310c6c7bb20435ef55a054f46c63418521a166443880bfb4f` |
| `pdf/roboto-flex-regular.ttf` | `ecd0964e419c6be3114c3c189e005eead549943739283726b5b4f255662a0a1b` |
| `roboto-bold.ttf` | `7d0b991ee3e0be7af01ad7ea8cd2beea6c00a25e679a0226b6737f079aafff86` |
| `roboto-flex.ttf` | `9b523f7d82593df0107173849ebb8c817471a1df4b4fb2c3cbf40cfd810c8281` |
| `roboto-regular.ttf` | `79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95` |
