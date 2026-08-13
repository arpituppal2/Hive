# Third-Party Notices

This project includes the following third-party software. Licenses are reproduced
as required by their respective terms.

---

## CefSwift (MIT)

**Source:** https://github.com/cef-swift/cef-swift (vendored at `Vendor/CefSwift`, commit `2dca11e`)

**License:**
```
MIT License

Copyright (c) 2026 Rajaniraiyn

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

**Additional notice:** This package vendors header files from, and downloads
binary distributions of, the Chromium Embedded Framework (CEF), which is
licensed under the BSD 3-Clause license. See https://github.com/chromiumembedded/cef
and the LICENSE.txt inside any CEF binary distribution.

---

## Chromium Embedded Framework (CEF) (BSD 3-Clause)

**Source:** Downloaded by CefSwift plugin at build time

**License:**
```
Copyright (c) 2008-2026, CEF Authors. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
3. Neither the name of Google Inc. nor the name of Chromium Embedded Framework
   nor the names of its contributors may be used to endorse or promote products
   derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
```

---

## mlx-swift-examples (MIT)

**Source:** https://github.com/ml-explore/mlx-swift-examples (version 2.29.1)

**License:**
```
MIT License

Copyright (c) 2024 ml-explore

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

**Transitive dependencies (also MIT/Apache-2.0):**
- mlx-swift (MIT)
- swift-transformers (MIT)
- swift-jinja (MIT)
- swift-numerics (Apache-2.0)
- swift-collections (Apache-2.0)
- GzipSwift (MIT)

---

## Sparkle (MIT)

**Source:** https://github.com/sparkle-project/Sparkle (version 2.6.0)

**License:**
```
MIT License

Copyright (c) 2006 Andy Matuschak and contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Brave adblock-rust (MPL-2.0)

**Source:** https://github.com/brave/adblock-rust (crate `adblock` v0.13, linked
into `native/adblock-ffi`, which powers network-level request filtering and
cosmetic blocking)

**License:** Mozilla Public License 2.0

MPL-2.0 is a file-level copyleft license: modifications to the MPL-licensed
files themselves must remain MPL-2.0, but the rest of the project is
unaffected. Full license text: https://www.mozilla.org/en-US/MPL/2.0/

---

## native/hive-fetch-boundary (Rust) — Internal

**Source:** `native/hive-fetch-boundary` in this repository

**License:** MIT (same as this project)

Built by `scripts/build-research-worker.sh` into the app bundle at release time.
Its direct dependencies are base64, rustls, sha2, serde, serde_json, and url (all
MIT/Apache-2.0), plus webpki-roots (CDLA-Permissive-2.0). Note: rustls is
triple-licensed (Apache-2.0 OR ISC OR MIT); webpki-roots bundles the Mozilla CA
certificate store under the CDLA-Permissive-2.0 data license.

---

## native/adblock-ffi (Rust) — Internal

**Source:** `native/adblock-ffi` in this repository

**License:** MIT (same as this project)

Wraps Brave adblock-rust (MPL-2.0, attributed above) plus the MIT/Apache-2.0
crates `once_cell`, `rmp`, `rmp-serde`, `url`, and `serde_json`.

---

## Swift Standard Library / Foundation / AppKit / SwiftUI

**Source:** Apple SDK (bundled with macOS)

**License:** Apple Public Source License / Swift License — covered by macOS SDK terms.