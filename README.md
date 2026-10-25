# Type Pinyin

武侠题材的拼音打字游戏（iPhone）。

## 编译运行

需要 macOS、Xcode 16 或更新、[XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
brew install xcodegen
cd app
xcodegen generate
open TypePinyin.xcodeproj
```

选 `TypePinyin` scheme 和一个 iPhone 模拟器运行。装到真机前，把 `app/project.yml` 里的 `DEVELOPMENT_TEAM` 和 `PRODUCT_BUNDLE_IDENTIFIER` 改成自己的，再重新 `xcodegen generate`。

引擎测试：`cd packages/DuelCore && swift test`
