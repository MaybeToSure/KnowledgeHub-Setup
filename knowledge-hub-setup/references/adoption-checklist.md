# KnowledgeHub 用户采用检查表

## 所有权边界

- 公开模板：只包含框架、规则、Skill、模板和工具。
- 用户实例：保存采用者自己的资料、笔记、项目入口和版本历史。
- GitHub 模式：采用者自己的私有仓库是远程基线，不把资料推送到模板仓库。

## 前置软件

Git、Git LFS、Codex 和 Obsidian为基础条件。GitHub 模式还需要 GitHub CLI，并由采用者登录自己的 GitHub 账号。

缺失软件只报告；除非用户明确授权，否则不要自动安装。认证检查不得输出 Token、SSH 私钥或凭据文件内容。

## 推荐采用流程

1. 选择 `WorkspaceRoot`；默认 `%USERPROFILE%\KnowledgeHub-Workspace`，KnowledgeHub 实例固定在其下的 `KnowledgeHub`。
2. 选择 GitHub 私有实例或纯本地实例。
3. GitHub 模式确认 `<owner>/<repo>` 属于采用者，且可见性为 private。
4. 运行部署脚本。
   新建实例必须显示 Framework `v0.4.2` / `0.4.2`；Existing 模式必须是 Framework `0.4.0` 或更高版本。
5. 验证 Git、Git LFS、目录结构和仓库健康。
6. 用 Obsidian 打开实例目录。
7. 用 Codex 打开同一目录，以自然语言要求仓库内的 `knowledge-hub` Skill 整理资料。
8. 新建“云飞随手记”专用 Codex 任务并打开同一目录；普通任务聊天不旁路记录。
9. 阅读实例内的 `docs/整体机制.md` 和 `docs/独立仓库创建与驱动.md`，了解记录、知识、任务与项目边界。
10. 确认 `.knowledge/local-config.json` 中的工作区与知识库路径正确；此文件是设备本地配置，不进入 Git。
11. Local 模式确认 `main` 没有上游分支，且 `framework` 的 push URL 已禁用。
12. 如需手机入口，单独采用 `KnowledgeHub-Mobile-Capture`；未完成公网 OAuth、权限和手机实测时保持默认关闭。

## Obsidian 推荐设置

- 新笔记默认位置：`00-Inbox/Human`。
- 附件默认位置：`10-Sources/Attachments`。
- 自动更新内部链接。
- 链接格式使用相对路径。
- 随手记 Markdown 位于 `00-Inbox/Human/Quick-Captures`，附件位于 `10-Sources/Attachments/Quick-Captures`，均可直接浏览和编辑。

## 验收

```powershell
git -C <知识库路径> status
git -C <知识库路径> remote -v
git -C <知识库路径> lfs env
powershell -ExecutionPolicy Bypass -File <知识库路径>\tools\verify-repository.ps1
```

GitHub 模式还要确认远程仓库显示为 private。首次放入 PDF、图片或 Office 文件后，再做一次 Git LFS 提交、推送和全新克隆抽查。

## 常见问题

- 目标目录非空：换用空目录，不自动合并。
- GitHub 仓库名已存在：选择另一个新名称；部署脚本不会复用并覆盖已有仓库。
- GitHub 认证失败：由采用者运行 `gh auth login`；不要传递 Token 给他人。
- Git LFS 缺失：安装后重新执行，不能把 LFS 指针当作完整文件。
- 只想部署后离线使用：选择 Local 模式；首次安装仍需联网下载固定 Framework 版本，之后可由用户添加自己的私有远程。
- Existing 实例缺少 `VERSION`、`framework.manifest.json` 或 `tools/setup.ps1`：这是早期扁平结构，先按 Framework 的升级与迁移文档处理，不能直接恢复。
- 不知道是否需要独立仓库：让 Codex 先判断；只有需要独立交付、版本、依赖、权限或复现环境时才创建。
