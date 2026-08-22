---
name: knowledge-hub-bootstrap
description: 在新电脑上创建或恢复 KnowledgeHub，检查 Git、Git LFS、Obsidian 与 Codex 前置条件，安全克隆知识库并运行初始化和健康检查。用于更换电脑、重装系统、首次部署或灾难恢复；不用于日常知识整理。
---

# Knowledge Hub Bootstrap

把目标限定为：让新电脑获得一个可用、可验证且不会误覆盖现有数据的 KnowledgeHub。本 Skill 负责部署；知识库落地后由仓库内的 `knowledge-hub` Skill 接管日常管理。

## 选择模式

- 用户已有个人知识库远程仓库：使用“恢复”模式，以该仓库为数据权威来源。
- 用户没有个人知识库：使用“新建”模式，从公开 KnowledgeHub Framework 创建本地实例。
- 用户没有说明时，先进行只读检查；只有“新建还是恢复”会改变数据来源，必须在执行前确认。

需要完整的人工检查表或遇到 Git/LFS、认证、Obsidian 问题时，读取 [references/new-computer-checklist.md](references/new-computer-checklist.md)。

## 安全边界

- 目标目录非空时停止，不合并、不删除、不覆盖。
- 不接受 URL 中嵌入的用户名、密码或 Token；使用 GitHub CLI、系统凭据或 SSH 认证。
- 新建模式只关联公开框架远程 `framework`，不会自动创建或推送个人远程仓库。
- 创建 GitHub 私有仓库、安装系统软件、改变全局 Git 配置或推送内容前取得明确授权。
- 恢复模式完成后必须执行 Git LFS 拉取，不能只验证 Markdown 文件。
- 不把“克隆成功”当作部署完成；必须运行仓库自带的初始化和健康检查。

## 执行

1. 只读检查操作系统、目标磁盘、`git`、`git lfs`、Obsidian、Codex 和 GitHub 认证状态；不要输出认证凭据。
2. 确认目标目录。Windows 默认优先使用 `D:\GitHub\KnowledgeHub`；没有 D 盘时使用用户文档目录下的 `KnowledgeHub`。
3. 执行 [scripts/bootstrap-knowledgehub.ps1](scripts/bootstrap-knowledgehub.ps1)：

   ```powershell
   # 新建本地实例
   .\scripts\bootstrap-knowledgehub.ps1 -Mode New

   # 从已有私有仓库恢复
   .\scripts\bootstrap-knowledgehub.ps1 -Mode Restore `
     -KnowledgeRepositoryUrl <个人知识库仓库地址>
   ```

4. 确认脚本输出中的 `setup_completed`、`verification_completed` 和 `lfs_pull_completed`。
5. 指导用户用 Obsidian 打开知识库目录，并在 Codex 中以该目录启动一个新任务。
6. 如果用户要求创建新的 GitHub 私有远程，先确认仓库名与可见性，再创建、关联和首次推送。

## 完成标准

- 目标目录是有效 Git 仓库且健康检查通过。
- 恢复模式的 Git LFS 对象已拉取。
- 新建模式没有把个人实例误关联为公开框架仓库的 `origin`。
- 用户知道 Obsidian 应打开哪个目录，以及下一步应在知识库任务中使用 `knowledge-hub` Skill。
- 报告尚未安装的软件、未配置的私有远程或未验证的二进制资料，不伪报完成。
