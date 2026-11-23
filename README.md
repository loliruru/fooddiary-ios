# 食迹 FoodDiary

食迹是一款用来记录饮食和身体感受的 iOS app。支持正餐、零食和独立身体记录，可从首页快速录入，也可按日期在「记录」中查看和编辑。自制餐可填写每条食材和采购来源，并可另存为 Combo 后套用。饮食、身体记录、照片和模板都保存在本机。

| 项目 | 配置 |
| --- | --- |
| 平台 | iOS 17.0 及以上 |
| 工程生成 | XcodeGen，配置在 `project.yml` |
| 应用 Bundle ID | `com.chinokafuu.fooddiary.ios` |
| 云端编译 | GitHub Actions，`macos-26` |

产品规格以 [V2](FoodDiary_Codex_Execution_Spec_v2.md) 为准。阶段进度和续接步骤见 [AGENTS.md](AGENTS.md)。

## 云端构建并下载 IPA

1. 将提交推送到 FoodDiary GitHub 仓库的 `main`。也可进入 **Actions**，选择 **iOS unsigned IPA**，使用 **Run workflow** 手动触发。[FoodDiary Actions](https://github.com/loliruru/fooddiary-ios/actions)
2. 打开对应提交的运行记录。构建日志中会列出 Xcode 和 SDK 版本，随后安装或调用 XcodeGen，生成工程并编译 arm64 真机 Release 版本。
3. 真机 Release 构建通过后，工作流会运行 iPhone 模拟器上的 SwiftData 和录入流程 XCTest。构建和测试成功后，在该次运行的 **Artifacts** 下载 `FoodDiary-unsigned-ipa-<commit SHA>`，解压得到 `FoodDiary-unsigned.ipa`。面向 `main` 的 PR 也会运行构建和测试。
4. 保留用于签名的原始 IPA。在 Windows PowerShell 可列出包内容，核对 `Payload/FoodDiary.app/Info.plist` 和 `Payload/FoodDiary.app/FoodDiary`。

   ```powershell
   tar -tf .\FoodDiary-unsigned.ipa
   ```

CI 不需要签名证书或 Apple ID。生成的工程、派生数据和 IPA 均由构建生成，Git 只跟踪源码和工程配置。

## 在 Windows 11 上侧载到 iPhone

1. 将 iPhone 连接到 Windows 11，允许电脑访问设备并在 Sideloadly 中选中该 iPhone。
2. 在 Sideloadly 选择下载并解压得到的 `FoodDiary-unsigned.ipa`，使用你自己的 Apple ID 重新签名并安装。下载的 IPA 需要签名才能在设备上安装。
3. 后续以相同的 Bundle ID 和 Apple ID 覆盖安装，避免先卸载，以保留本机数据。首次设备授权和个人签名有效期按设备及签名工具提示处理。

应用的数据库和照片保存在 iPhone 的 App 沙盒中，并排除在系统备份外。GitHub Actions artifact 只包含构建产物。Phase 5 提供完整 JSON 备份和 CSV 导出。

### Phase 2 真机验收

- 用首页分别记录正餐和零食，再到「记录」查看时间、名称和类型。强制退出 App 后重新打开，查看、编辑并删除一条记录。
- 录入不收藏的名称后检查「历史与常用」的两个列表。显式保存一个店铺和一个食物，再在设置中改名或删除，核对历史里的原名称。
- 给同一餐录入来自不同来源的食材，也保留一条未填来源的食材。重开后核对详情。重复上一条零食，检查新事件时间和填充内容。
- 从系统照片选择器选择照片，确认重开了还能查看。分别试一次取消更换、保存更换及删除含照片的记录。

### Phase 3 真机验收

- 覆盖安装后查看已有饮食、食材、照片和常用项。从首页新增一条昨晚开始的身体记录，感受留空。勾选腹泻并调整次数，保存后在昨天的时间线查看，核对开始时间和填写时间。编辑并取消勾选腹泻，确认次数隐藏，再删除该身体记录。
- 从餐详情录入两条身体记录，其中一条主动选择「关联这顿餐」。核对独立记录和餐详情，删除该餐后再次从时间线打开身体记录。
- 保存一份自制餐，再新建同类餐食并点「保存为 Combo」，随后取消饮食录入。新建自制餐时套用 Combo，调整本次的采购来源并保存。在设置的「自制餐 Combo」中改名和删除模板，核对两份自制餐各自的食材明细。

## App Icon

图标以瓷盘和嫩叶为主题，通过内置 ImageGen 生成。应用使用 [1024×1024 PNG](FoodDiary/Assets.xcassets/AppIcon.appiconset/AppIcon.png)。

<details>
<summary>ImageGen 提示词</summary>

Create a finished original 1024 × 1024 square iOS app icon for 食迹, a warm private food and wellbeing diary. Flat, modern emblem: one large ivory ceramic plate viewed from directly above, with a clean cream rim and a simple two-leaf sage-green sprout sweeping diagonally inside the plate. Use a solid muted deep pine-green background (#244C3E) that extends all the way to all four square edges, warm porcelain (#FAF6E9), and sage (#6D9379). Center the emblem and make it occupy about 68 percent of the canvas so it remains instantly legible at 32 pixels. Use confident shapes, generous negative space, at most one inner rim line, and crisp edges. Sophisticated, friendly, quiet. No lettering, numbers, branding, transparency, outer border, pre-rounded outer corners, drop shadow, mockup, photographic detail, or decorative objects. Single icon only, edge to edge opaque square.

</details>
