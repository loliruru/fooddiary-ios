# 食迹开发与交接

## 规格与开发规则

- 每次接手先通读根目录 [FoodDiary_Codex_Execution_Spec_v2.md](FoodDiary_Codex_Execution_Spec_v2.md)，再检查 Git 状态。该文件是唯一有效的产品规格。第 12 节覆盖冲突的旧设计，阶段安排以第 8 节和第 12.10 节合并后的范围为准。
- 按阶段实施。保留已有工作，每阶段完成检查、更新本文件的进展和验收证据、单独提交 Git，然后暂停并等待用户确认。
- 原生 SwiftUI，最低 iOS 17.0，XcodeGen 以根目录 `project.yml` 为输入。应用名称「食迹」，工程、目标和 Scheme 为 `FoodDiary`，Bundle ID 为 `com.chinokafuu.fooddiary.ios`。保留 Bundle ID 以支持后续覆盖安装。
- 界面用简体中文，文案集中放在字符串目录。日期和时间使用设备时区显示，存储事件的真实时间。优先适配 iPhone 竖屏，兼顾深色模式、动态字体、无障碍标签和 Reduce Motion。
- 使用 SwiftData 和应用沙盒。饮食、健康、照片和模板数据都保存在本机。用户主动选择照片时用系统选择器，删除饮食事件时清理对应照片。首版排除账号、云同步、追踪、广告、定位、营养分析、社交和医疗诊断。店铺图标使用通用图标、文字或用户自选合法图片。
- 健康功能用「时间上可能相关」「待观察」等措辞。候选用于人工复核，避免把单次不适或时间先后视为因果证据。

## V2 数据和交互边界

- `IntakeEvent` 统一保存正餐和零食/加餐。正餐区分外卖、堂食、自制。零食拥有自己的摄入时间，可填品牌、购买来源、数量等，并能快速重复上一条零食。
- `SavedPlace` 和 `SavedFood` 必须分别经用户点击各自的保存操作才写入。输入、保存饮食、使用历史建议都不会自动收藏。历史搜索与收藏列表各自提供快捷选择。改名或删除收藏只影响收藏项，历史继续显示当时的名称。
- 自制餐的 `IngredientItem` 可有多条，每条独立记录名称、可选采购来源、数量和备注。支持多个来源、同一来源采购多种食材、部分或全部留空来源，以及只填餐名。历史保留每条明细及其来源。
- `MealCombo` 是独立的自制餐模板，仅在用户选择「保存为 Combo」时创建。选择模板时复制内容到新餐。本次编辑、模板编辑和模板删除彼此独立，既有餐食和症状关联保持完整。
- `SymptomEvent` 是独立事件，症状开始时间 `symptomTime` 与填写时间 `recordedAt` 分开。首页和时间线都可独立新增；从餐详情进入也创建独立事件。用户可显式选择关联某餐，仍可回溯其他摄入。腹泻次数仅在选中腹泻时展示，持久化值为非负整数。未填感受保持未知。
- Phase 4 以症状开始时间为基准，查询此前 48 小时的所有摄入，窗口时长集中配置。按时间倒序显示日期、时间差、自制餐食材及来源，候选初始为未判断。由用户逐条判断怀疑、暂不认为有关或不确定，`SymptomExposureLink` 保存选择。允许多个怀疑候选，也允许全部保持未判断。
- 避雷分别按食物、食材、店铺聚合，保留总摄入次数、用户怀疑次数、有不适证据的记录数、原始记录入口和手动状态。沿用第 3.4 节中兼容的单次与至少两次的显示规则，以及少样本提示。采购店铺和食材分别统计。
- 模型使用稳定 UUID，显示原始名称，搜索和聚合时归一化。用云端 XCTest 验证 SwiftData 关系、数组持久化和删除规则，尤其是模板与历史快照的独立性。

## 阶段与验收

| 阶段 | 实施范围 | 重点验收 |
| --- | --- | --- |
| Phase 0 | Git、XcodeGen、最小 SwiftUI 首页、云端 unsigned IPA、README 和交接 | `main` push 触发成功，下载 artifact 后核对 IPA 内的 `Payload/FoodDiary.app` |
| Phase 1 | 颜色、字体、卡片和按钮、四个 Tab 的静态骨架、空状态、深色模式、原创 1024×1024 App Icon | 首页、记录、避雷、设置布局完整，动效尊重 Reduce Motion，云端构建成功 |
| Phase 2 | 正餐与独立零食 CRUD、自制餐多食材及采购来源、本地 SwiftData、照片和标签、历史快捷选择、常用店铺与食物管理及显式保存 | 重启仍可读取；临时输入未进收藏；删除收藏保留历史；多来源、零食复用和照片生命周期正确 |
| Phase 3 | 独立症状 CRUD、三个首页快速入口、身体感受和症状表单、可选手动关联、Combo 显式创建、复制、编辑、删除 | 开始与填写时间分别保存；腹泻次数显示与边界正确；可脱离餐食保存；Combo 使用、修改和删除保留历史 |
| Phase 4 | 48 小时跨日候选与用户判断、记录时间线搜索和筛选、可追溯统计和手动避开状态 | 昨晚 22:30 的零食出现在次日 08:00 症状候选中且时间差为 9.5 小时；可标多个或全不判断；统计有分母、原始记录和边界测试 |
| Phase 5 | CSV/JSON、分享面板、清空确认、隐私说明、无障碍与发布候选 | 导出覆盖正餐、零食、食材、采购来源、独立症状、关联判断、常用店铺、食物及 Combo；正确处理中文、逗号、引号、换行；备份导入/导出保留独立历史和关联；在 iPhone 验收 |

## 构建与验证

- Windows 只运行可用的静态检查与脚本检查。GitHub-hosted `macos-26` 执行 XcodeGen、真机 Release 编译及后续 XCTest；编译路径不需要 Windows 安装 Xcode 或模拟器。
- `.github/workflows/ios-build.yml` 响应推送 `main`、面向 `main` 的 PR 和手动触发。`scripts/build-ios-unsigned.sh` 使用 `iphoneos` 和 arm64，关闭代码签名，验证并产出 `build/FoodDiary-unsigned.ipa`，由 push 或手动运行上传。
- GitHub 只存源码和构建产物。Apple ID、证书及饮食数据均不进入仓库、GitHub Secrets 或构建日志。Windows 下载构建产物后通过 Sideloadly 和用户自己的 Apple ID 重新签名，步骤见 [README.md](README.md)。交互与覆盖安装在 iPhone 验证。

## 当前进展与接手步骤

- 2026-11-22 完成 Phase 0。初始化时只有 V2 原始规格文件。已建立最小工程、单一空首页、构建脚本和工作流，并通过配置一致性、字符串目录 JSON、`bash -n` 和 `git diff --cached --check` 检查。V2 原文件校验值与初始化前一致。
- 用户指定的远端为 [loliruru/fooddiary-ios](https://github.com/loliruru/fooddiary-ios)。Phase 0 工程提交 `f3df870d3e5ca65d66ea32da82b8705d041d4312` 已推送到 `main`，触发 [Actions run 45038468375](https://github.com/loliruru/fooddiary-ios/actions/runs/45038468375)，云端构建与上传成功。
- 已下载 [Phase 0 artifact](https://github.com/loliruru/fooddiary-ios/actions/runs/45038468375/artifacts/14759999219) 并解包检查 `FoodDiary-unsigned.ipa`。确认含 `Payload/FoodDiary.app`、arm64 可执行文件、iOS 17.0 最低版本、正确 Bundle ID 和简体中文字符串；包内无签名资源和描述文件。IPA SHA-256 为 `d3b7c389ff573c5acf7422cee340042acf3afddca4feb580fcd38ddb63dfd420`。
- 新会话先读 V2 第 12 节，运行 `git status --short --branch`、`git log -1 --oneline` 和 `git remote -v` 核对实际状态。若 Windows Git 提示本仓库所有权不一致，可用 `git -c safe.directory=C:/Dev/Codex/iPhone/FoodDiary` 运行对应命令。
- 2026-11-22 用户确认后实施 Phase 1。应用入口通过 `DiaryTabs` 打开首页、记录、避雷和设置。四页共享 `DiaryTheme`、卡片和按钮样式，按钮按压反馈读取 Reduce Motion。首页三个录入入口显示可关闭的静态预览。原创 1024×1024 App Icon 已纳入 Asset Catalog，构建号为 2。
- Phase 1 工程提交 `dd6424d951e075eaa2e4119c5f937592f3d7c85c` 已推送到 `main`。本地检查确认 30 条简体中文文案与引用一致、浅色和深色文字配色通过对比度检查、图标为不透明 RGB PNG。[Actions run 45040212132](https://github.com/loliruru/fooddiary-ios/actions/runs/45040212132) 真机 Release 构建成功。已下载 [Phase 1 artifact](https://github.com/loliruru/fooddiary-ios/actions/runs/45040212132/artifacts/14761840625)，确认 IPA 内含 `Payload/FoodDiary.app`、arm64、App Icon 和中文资源。IPA SHA-256 为 `248d68bc322bde9dce24ddc4134411d9add6a20f84c79f3caf2e73d23bbf356d`。
- 2026-11-23 完成 Phase 1 云端界面验收。独立验收分支 `codex/phase1-visual-check` 的 iPhone 17 模拟器（iOS 26.5）跑通浅色和深色的四 Tab 导航、回到首页、三个录入预览的打开与关闭，以及最大辅助字号下的身体不适入口，并复核了两套外观截图。[模拟器运行](https://github.com/loliruru/fooddiary-ios/actions/runs/45041213466) · [截图产物](https://github.com/loliruru/fooddiary-ios/actions/runs/45041213466/artifacts/14761973732)
- 2026-11-23 用户确认 Phase 1 后实施 Phase 2。首页和记录页接入正餐与零食录入、按天浏览与详情；详情可编辑、复制或二次确认后删除。自制餐的食材按表单顺序保存，每条可独立填写采购来源、份量和备注。历史与常用分别提供快捷选择，常用项从录入页显式确认保存或在设置管理，饮食历史持久化原始名称。
- Phase 2 构建号为 3。本机 SwiftData 关闭 CloudKit，数据库和照片目录排除在系统备份外。照片从系统选择器读取，缩放为最长边 1600 像素的 JPEG，并在保存成功后清理被替换、移除或删除的照片。复用时生成独立照片文件。
- Windows 静态检查通过 Swift 源文件语法、XcodeGen 与工作流 YAML、98 条字符串键、照片测试样本及 Git 差异检查。
- Phase 2 工程提交 `3f5c012dc276ce27cb7744be2722e981ae785360`、`c114617d8a445154d2e6b29592ebc2237699098d` 已推送到 `main`。[Actions run 45178139000](https://github.com/loliruru/fooddiary-ios/actions/runs/45178139000) 的 arm64 真机 Release 构建成功，iPhone 17 Pro 模拟器（iOS 26.2）的 5 个 SwiftData 测试和 1 个界面测试全部通过。已验证重开存储后的标签与食材顺序、食材删除、收藏独立性、零食复用与照片生命周期，以及从首页录入零食后重启、从记录页编辑和删除。
- 已下载 [Phase 2 artifact](https://github.com/loliruru/fooddiary-ios/actions/runs/45178139000/artifacts/14820796509)，确认 `FoodDiary-unsigned.ipa` 含 `Payload/FoodDiary.app`、arm64 可执行文件、iOS 17.0 最低版本、正确 Bundle ID、App Icon 和 98 条简体中文字符串，包内无签名资源和描述文件。IPA SHA-256 为 `e37748df377914dc2120ce72ecd1db019ce53a39cfccb41b53a3a2af2d1e13a9`。系统照片选择器与侧载覆盖安装按 README 在 iPhone 验收。
- 2026-11-23 用户确认 Phase 2 后实施 Phase 3，构建号为 4。首页和时间线均可新增独立身体记录，餐详情提供可选的手动关联。时间线按开始时间显示，填写时间单独保存。感受留空保持未知，取消勾选腹泻后保存的次数归零。删除餐食时解除关联并保留身体记录。
- 自制餐通过「保存为 Combo」立即保存模板，套用时复制餐名和有序食材到本餐草稿。在设置可独立编辑或删除模板。
- 2026-11-24 完成 Phase 3 云端验收。Windows 检查通过 31 个 Swift 源文件的语法、146 条简体中文字符串及引用、XcodeGen 与工作流 YAML、构建脚本语法和 Git 差异。Phase 3 最终工程提交 `ed55cac0019a05e238f1a6c4b87c32123f482aad` 已推送到 `main`。[Actions run 45212309797](https://github.com/loliruru/fooddiary-ios/actions/runs/45212309797) 的 arm64 真机 Release 构建成功，iPhone 17 Pro 模拟器（iOS 26.2）的 9 项 SwiftData 测试和 3 项界面测试全部通过。
- 云端测试覆盖 Phase 2 存档升级、症状开始与填写时间、腹泻次数边界、身体记录与餐食的独立删除、Combo 复制与历史快照，以及在界面创建、套用、编辑和删除 Combo、从首页录入独立症状并在重启后编辑和删除。
- 已下载 [Phase 3 artifact](https://github.com/loliruru/fooddiary-ios/actions/runs/45212309797/artifacts/14836179687)，验证 `FoodDiary-unsigned.ipa` 含 `Payload/FoodDiary.app`、arm64、最低 iOS 17.0、正确 Bundle ID、App Icon 和 146 条简体中文字符串。包内无签名资源和描述文件。IPA SHA-256 为 `25c984f3eb449d1cbe7a568bc839170a9dcaedb8fc9e339c71c7d569fb80a291`。
- 2026-11-24 根据用户反馈修复 Phase 3 的 Combo 保存，构建号为 5。只有食材时自动命名，点击后显示成功或具体缺项。保存的模板在取消本餐后仍保留，新建餐食时可直接套用并切换到自制。[Actions run 45420119089](https://github.com/loliruru/fooddiary-ios/actions/runs/45420119089) 的 arm64 Release 构建成功，iPhone 17 Pro（iOS 26.2）的 10 项单元与存储测试和 3 项界面测试全部通过。验收工程提交为 `8436ec1916440ad25d470eddbefe8731a1599e38`。
- Windows 已检查 31 个 Swift 文件与 147 条字符串键，并下载 [Combo 修复 IPA](https://github.com/loliruru/fooddiary-ios/actions/runs/45420119089/artifacts/14933874053) 核对 arm64、iOS 17.0、构建号 5、Bundle ID、中文资源及无签名打包。IPA SHA-256 为 `24a10608eb91dc8a46f7845fe668aa682c028a009d1932ede895e283b599bb0a`。
- Phase 4 待用户确认。iPhone 侧载覆盖安装和真机交互按 [README.md](README.md) 的 Phase 3 步骤验收。
- 后续阶段更新本节的完成范围、提交、云端 run、验收结果及待办。真机交互按 README 的侧载流程在 iPhone 上验收。
