非常理解你的场景 👍
公司网络封闭、VS Code 无法在线访问 Marketplace（`marketplace.visualstudio.com`）的情况非常常见。
我们完全可以 **离线下载插件 `.vsix` 文件**，再打包手动安装。

下面是完整、可落地的做法👇

---

## 🧩 一、目标

你想要：

1. 直接从 Marketplace 获取 VSCode 插件（如 `GitHub.copilot`）；
2. 离线保存成 `.vsix`；
3. 在无网络的环境中导入使用。

---

## 🧰 二、离线下载 VSCode 插件的三种方法

---

### **方法 1️⃣：使用官方 API 生成 `.vsix` 下载链接（推荐）**

每个 Marketplace 插件页面如：

```
https://marketplace.visualstudio.com/items?itemName=GitHub.copilot
```

实际插件 ID：

```
GitHub.copilot
```

使用以下通用下载地址模板：

```
https://marketplace.visualstudio.com/_apis/public/gallery/publishers/<PublisherName>/vsextensions/<ExtensionName>/<Version>/vspackage
```

👉 对于 Copilot：

```
https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/copilot/1.215.0/vspackage
```

> 版本号（`1.215.0`）可以从 Marketplace 页面 **“Version History”** 查到。

下载后会得到：

```
GitHub.copilot-1.215.0.vsix
```

---

### **方法 2️⃣：使用命令行下载（有外网机器）**

在一台有网络的电脑上执行：

```bash
code --install-extension GitHub.copilot --force
```

安装成功后 `.vsix` 文件会缓存到：

```
~/.vscode/extensions/github.copilot-1.215.0/
```

然后你可以：

```bash
cd ~/.vscode/extensions
zip -r github.copilot-1.215.0.zip github.copilot-1.215.0/
```

拷贝到内网电脑后，执行：

```bash
code --install-extension github.copilot-1.215.0.zip
```

---

### **方法 3️⃣：使用外部镜像站下载（若可访问）**

例如：

- [https://open-vsx.org/](https://open-vsx.org/) （社区镜像）
  搜索插件名（部分非官方插件版本较旧）；
- [https://www.vsixhub.com/vsix/](https://www.vsixhub.com/vsix/) （专门提供 `.vsix` 直链下载）。

> ⚠️ 注意：部分插件（如 GitHub Copilot）**仅在官方 Marketplace 发布**，无法通过 open-vsx 下载。

---

## 🧩 三、内网安装步骤

1. 将 `.vsix` 文件拷贝到内网电脑；
2. 打开 VS Code → 扩展视图（Ctrl+Shift+X）；
3. 点击右上角的 `...` → “Install from VSIX...”；
4. 选择 `.vsix` 文件即可。

或命令行方式：

```bash
code --install-extension GitHub.copilot-1.215.0.vsix
```

---

## 🧩 四、批量封装打包脚本示例

如果你要下载多个插件并一次性导入，可在外网机执行：

```bash
#!/bin/bash
plugins=(
    "GitHub.copilot"
    "ms-python.python"
    "ms-toolsai.jupyter"
)

mkdir -p vscode-plugins
for p in "${plugins[@]}"; do
    echo "Downloading $p..."
    code --install-extension "$p" --force
    cp -r ~/.vscode/extensions/${p,,}* vscode-plugins/
done

cd vscode-plugins
zip -r vscode-plugins.zip ./
```

然后将 `vscode-plugins.zip` 拷贝进内网，解压后执行：

```bash
code --install-extension <plugin-folder>
```

---

## ✅ 五、验证安装

在内网执行：

```bash
code --list-extensions
```

若输出包含：

```
GitHub.copilot
```

说明离线安装成功 ✅

---

是否希望我帮你写一个 **一键离线下载脚本（支持输入插件名 + 自动生成 vsix 文件）**？
可以直接在外网环境运行，生成压缩包供内网导入。
