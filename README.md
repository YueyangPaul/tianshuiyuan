# 甜水园食堂

每周家宴点菜网页：朋友点菜、写自定义菜和口味；主人维护菜单库、按日期开一期、看谁点了什么、记录往期成品照片。

- 网页：纯静态，放在 GitHub Pages（`index.html` + `vendor/`）
- 数据：Supabase（`setup.sql` 建表和权限），配置写在 `config.js`
- 没上传照片的菜用 AI 生成示意图（pollinations.ai），主人登录后生成一次并存进数据库

## 首次设置

1. 在 Supabase 新建项目，打开 SQL Editor，粘贴 `setup.sql` 全部内容运行。
2. Authentication → Users → Add user，填主人的邮箱和密码（勾选 Auto Confirm）。第一个创建的用户就是主人。
3. Authentication → Sign In / Providers，关掉 “Allow new users to sign up”。
4. 把 Project URL 和 anon（或 publishable）key 填进 `config.js`。
5. 仓库 Settings → Pages，Source 选 `main` 分支根目录。

分享某一期：网页链接后面加 `#m20261101`（m + 日期），主人后台的「复制邀请」会自动带上。
