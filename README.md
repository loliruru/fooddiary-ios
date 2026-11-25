# 食迹 FoodDiary

食迹是一款用来记录饮食和身体感受的 iOS app。支持正餐、零食和独立身体记录，可从首页快速录入，也可在「记录」中搜索和筛选。自制餐可填写食材和采购来源，并可另存为 Combo 后套用。身体记录可复核开始前 48 小时的摄入，「避雷」可查看统计和原始记录。饮食、身体记录、照片和模板都保存在本机。

| 项目 | 配置 |
| --- | --- |
| 平台 | iOS 17.0 及以上 |
| 发布候选 | 1.0.0（构建 7） |
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

应用的数据库和照片保存在 iPhone 的 App 沙盒中，并排除在系统备份外。GitHub Actions artifact 只包含构建产物。

## 备份、恢复与隐私

- 在「设置 → 备份与数据」选择「导出 JSON 备份」，再用系统分享面板存入「文件」或发送到自己选择的位置。JSON 包含记录、照片、关联判断、手动避开状态、常用项和 Combo。
- 选择「恢复 JSON 备份」，从「文件」打开以前导出的备份。核对记录数和模板数后确认替换。如果需要保留当前资料，先单独保存一份 JSON。恢复保留原记录 UUID 和关联，收藏与 Combo 可继续独立编辑或删除。
- 选择「导出 CSV」可在表格工具中筛选和核对记录。文件采用带 BOM 的 UTF-8，`recordType` 标识行类型，UUID 列可关联饮食、食材、症状及 Combo。日期包含导出时的本地时区偏移，标签和症状列表使用 JSON 数组。CSV 包含文本记录和判断。照片随 JSON 备份保存。
- 「清空全部数据」须再次确认，会删除本机的记录、照片、模板和手动状态。用系统分享面板保存的副本在所选位置管理。

JSON 的 `formatVersion` 为 1，日期为 Unix 秒数，保留实际发生和填写时间。照片以 Base64 JPEG 保存在对应记录中。备份含个人资料。应用无需账号、无追踪或广告，只有在选照片、导出或恢复时打开对应系统面板。

### Phase 2 真机验收

- 用首页分别记录正餐和零食，再到「记录」查看时间、名称和类型。强制退出 App 后重新打开，查看、编辑并删除一条记录。
- 录入不收藏的名称后检查「历史与常用」的两个列表。显式保存一个店铺和一个食物，再在设置中改名或删除，核对历史里的原名称。
- 给同一餐录入来自不同来源的食材，也保留一条未填来源的食材。重开后核对详情。重复上一条零食，检查新事件时间和填充内容。
- 从系统照片选择器选择照片，确认重开了还能查看。分别试一次取消更换、保存更换及删除含照片的记录。

### Phase 3 真机验收

- 覆盖安装后查看已有饮食、食材、照片和常用项。从首页新增一条昨晚开始的身体记录，感受留空。勾选腹泻并调整次数，保存后在昨天的时间线查看，核对开始时间和填写时间。编辑并取消勾选腹泻，确认次数隐藏，再删除该身体记录。
- 从餐详情录入两条身体记录，其中一条主动选择「关联这顿餐」。核对独立记录和餐详情，删除该餐后再次从时间线打开身体记录。
- 新建自制餐，餐名留空，添加「面条」和「菠菜」。点击「保存为 Combo」，确认收到保存提示后取消本餐。再次点「记录一餐」，直接从「套用 Combo」选中刚才的模板，确认餐名和两条食材均已填入。保存餐食后，在设置的「自制餐 Combo」中改名或删除模板，核对历史餐食的食材仍完整。

### Phase 4 真机验收

- 覆盖安装后查看已有记录。把一条零食的摄入时间设为昨天 22:30，把一条新的身体记录开始时间设为今天 08:00。保存后在身体记录中核对零食的日期和「距症状开始约 9.5 小时」，也核对其他 48 小时内的自制餐及其食材来源。
- 保留所有候选为「未判断」，退出后回到详情确认仍可逐条复核。标记两个候选为「我怀疑与此有关」，另选一个「不确定」，重开应用后核对。修改症状开始时间时，候选随窗口变化。原判断保存，只有摄入仍位于窗口时才纳入候选统计。
- 在「记录」中按名称或采购来源搜索，组合日期、类型、感受和症状筛选。核对日期以设备本地日历为准，并检查无匹配结果和清除筛选的操作。
- 在「避雷」切换食物、食材及店铺与品牌，核对分母、怀疑次数、原始饮食和身体记录。手动选择「暂时避开」「已重新尝试」或「不再关注」，检查重启后状态。每个对象在同一餐只计一次摄入。明确关联且填写「不舒服」和症状的摄入计入不适次数。少于 5 次摄入时显示少样本提示。

### Phase 5 真机验收

- 用相同 Bundle ID 和 Apple ID 覆盖安装。打开「设置」，核对 1.0.0（构建 7），再查看升级前的饮食、照片、身体记录、关联判断和模板。
- 在「备份与数据」分别导出 CSV 和 JSON，用分享面板存入「文件」。用表格打开 CSV，核对中文、逗号、引号、换行和本地时区。检查食材与采购来源、关联 UUID、模板及手动避开状态。
- 用测试记录演练清空与恢复。先保存 JSON 并确认文件可选。打开「清空全部数据」后取消，确认记录仍在，再确认清空。选择刚才的备份，核对摘要后恢复并重新打开 App。打开原始记录验证照片、关联及食材顺序。删除一个常用项或 Combo，再从历史查看原记录。
- 分别在浅色和深色模式下操作。用大字号和 VoiceOver 检查首页、记录、避雷、设置，完成一次录入、搜索及备份操作，确认按钮和表单在键盘弹出时仍可访问。开启「减少动态效果」后再试一次按钮和感受选择。

## App Icon

图标以瓷盘和嫩叶为主题，通过内置 ImageGen 生成。应用使用 [1024×1024 PNG](FoodDiary/Assets.xcassets/AppIcon.appiconset/AppIcon.png)。

<details>
<summary>ImageGen 提示词</summary>

Create a finished original 1024 × 1024 square iOS app icon for 食迹, a warm private food and wellbeing diary. Flat, modern emblem: one large ivory ceramic plate viewed from directly above, with a clean cream rim and a simple two-leaf sage-green sprout sweeping diagonally inside the plate. Use a solid muted deep pine-green background (#244C3E) that extends all the way to all four square edges, warm porcelain (#FAF6E9), and sage (#6D9379). Center the emblem and make it occupy about 68 percent of the canvas so it remains instantly legible at 32 pixels. Use confident shapes, generous negative space, at most one inner rim line, and crisp edges. Sophisticated, friendly, quiet. No lettering, numbers, branding, transparency, outer border, pre-rounded outer corners, drop shadow, mockup, photographic detail, or decorative objects. Single icon only, edge to edge opaque square.

</details>
