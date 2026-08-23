---
name: knowledge-hub-setup
description: 帮助其他用户首次采用 KnowledgeHub，从公开模板创建用户自己的 GitHub 私有知识库或纯本地实例，并配置 Git LFS、运行初始化与健康检查。也可连接用户已有实例；不用于日常知识整理。
---

# KnowledgeHub Setup

目标是让采用者获得一套完全归其本人或组织所有的 KnowledgeHub。公开框架只是模板来源，不是用户资料的远程仓库。实例落地后，由实例内的 `knowledge-hub` Skill 接管日常管理；本落地包同时安装 `yunfei-quick-capture`，用于专用 AI 入口中的低摩擦记录。

## 选择实例方式

- `GitHub`：推荐。使用公开模板创建采用者自己的 GitHub 私有仓库，然后克隆到本地。
- `Local`：只创建本地实例，不创建采用者的远程仓库。
- `Existing`：连接采用者已经拥有的知识库仓库。

执行前确认目标目录和实例方式。GitHub 模式还需确认采用者自己的 `<owner>/<repo>`；该参数本身即是创建私有仓库的明确目标，但执行前仍应向用户复述仓库名和 `private` 可见性。

需要前置软件、Obsidian 设置、验收或故障处理时，读取 [references/adoption-checklist.md](references/adoption-checklist.md)。

## 不变量

- 目标目录非空时停止，不合并、不删除、不覆盖。
- 用户资料只进入用户自己的实例；不得提交到公开模板或本部署仓库。
- GitHub 模式只能创建私有仓库，除非用户另外明确要求公开。
- 不接受 URL 内嵌的用户名、密码或 Token；使用 GitHub CLI、系统凭据或 SSH。
- 不自动安装系统软件，不改变全局 Git 配置。
- 不把“克隆成功”当作落地完成；必须运行实例自带的初始化和健康检查。
- Existing 模式必须拉取 Git LFS 对象。

## 工作流

1. 只读检查操作系统、可用目录、Git、Git LFS、Codex、Obsidian；GitHub 模式还要检查 `gh auth status`，但不得输出凭据。
2. 让用户选择 `GitHub`、`Local` 或 `Existing`。
3. 确认目标路径。不要假定采用者使用特定盘符；未指定时推荐用户文档目录下的 `KnowledgeHub`。
4. 调用 [scripts/setup-knowledgehub.ps1](scripts/setup-knowledgehub.ps1)。
5. 检查输出中的初始化、健康检查、LFS 和远程归属状态。
6. 指导用户用 Obsidian 和 Codex 打开同一知识库目录。
7. 指导用户建立“云飞随手记”专用任务；普通任务聊天不得旁路记录，Obsidian 与专用任务共同编辑同一份 Markdown。
8. 说明后续独立课程、工程、实验、研究或写作仓库默认由实例内的 `knowledge-hub` Skill 根据自然语言创建；人工手工创建后也可要求其审核和登记。

示例：

```powershell
# 创建采用者自己的 GitHub 私有实例
.\scripts\setup-knowledgehub.ps1 -Mode GitHub `
  -GitHubRepository <owner>/<repo> -Destination <本地目录>

# 纯本地实例
.\scripts\setup-knowledgehub.ps1 -Mode Local -Destination <本地目录>

# 连接采用者已有实例
.\scripts\setup-knowledgehub.ps1 -Mode Existing `
  -KnowledgeRepositoryUrl <仓库地址> -Destination <本地目录>
```

## 完成标准

- 采用者拥有独立知识库实例，且目标目录是健康的 Git 仓库。
- GitHub 模式的 `origin` 指向采用者自己的私有仓库。
- Local 模式没有 `origin`，公开模板仅命名为 `framework`。
- Existing 模式的普通 Git 和 Git LFS 内容均已恢复。
- 用户知道如何在 Obsidian 和 Codex 中打开实例，以及如何开始使用仓库内的 `knowledge-hub` Skill。
- 用户知道如何使用专用“云飞随手记”任务和 Obsidian 记录，并理解普通任务聊天不旁路记录。
- 用户知道独立工作仓库位于 KnowledgeHub 之外；未明确授权时不创建远程、不推送。
