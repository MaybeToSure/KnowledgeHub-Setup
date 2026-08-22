# 新电脑部署检查表

## 前置软件

必需：Git、Git LFS、Codex、Obsidian。GitHub CLI 可选，用于登录、创建私有仓库和检查远程状态。

先使用 `Get-Command`、`git --version`、`git lfs version` 和应用安装路径做只读检查。缺失软件只报告；除非用户明确授权，否则不要自动安装。

## 恢复已有知识库

1. 确认个人知识库远程仓库地址，不把 Token 写进 URL。
2. 确认目标目录为空或不存在。
3. 运行恢复模式脚本。
4. 检查普通 Git 对象和 Git LFS 对象。
5. 确认 `origin` 指向用户自己的知识库，而不是公开框架。
6. 用 Obsidian 打开知识库，并用 Codex 打开同一目录。

## 新建知识库

1. 从公开框架创建本地实例。
2. 脚本把公开仓库远程重命名为 `framework`，避免误推送个人资料。
3. 用户需要远程同步时，创建一个新的 GitHub 私有仓库作为 `origin`。
4. 审查提交内容，完成首次推送。

## Obsidian

- 选择“打开本地文件夹作为仓库”。
- 新笔记默认位置推荐设为 `00-Inbox/Human`。
- 附件默认位置推荐设为 `10-Sources/Attachments`。
- 启用自动更新内部链接，链接格式使用相对路径。

## 验收命令

```powershell
git -C <知识库路径> status
git -C <知识库路径> lfs ls-files
powershell -ExecutionPolicy Bypass -File <知识库路径>\tools\verify-repository.ps1
```

重要资料恢复后，抽查至少一个 Markdown、一个 PDF 或图片等 LFS 文件，以及一个项目入口中的远程地址和提交号。

## 常见阻塞

- 私有仓库认证失败：使用 `gh auth login`、系统凭据管理器或 SSH；不要把 Token 发到聊天或写入脚本。
- `git lfs` 不存在：安装 Git LFS 后重新运行恢复，不要把只有 LFS 指针文件的仓库当作完整恢复。
- 目标目录非空：换用新目录，或由人工明确决定如何处理原目录。
- Obsidian 未安装：知识文件仍可用普通编辑器读取，但 Obsidian 界面能力暂不可用。
- 健康检查失败：保留现场，根据错误修复；不得继续自动推送。
