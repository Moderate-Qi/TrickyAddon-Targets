# 构建与发行

基准提交与增强版本见 `publication/UPSTREAM.json`。以下命令在仓库根目录运行；Windows 使用 `gradlew.bat`，Linux/macOS 使用 `./gradlew`。

获取子模块：

```sh
git submodule update --init --recursive
```

## TrickyAddon 739674-targets.2

环境：Node、pnpm、Python 3；TypeScript/Vite 与其他前端依赖版本由 webui/pnpm-lock.yaml 固定。

```sh
pnpm --dir webui install --frozen-lockfile
pnpm --dir webui build
python publication/package_module.py --output publication-output/TrickyAddon-739674-targets.2.zip
```

Vite 将前端写入 module/webui，打包入口与 module 中的刷入脚本、target-automation.sh、target-merge.awk 一起组装 SukiSU ZIP。默认模式、自动添加和备份恢复的首选源码位于 `webui/src/target_automation.ts`、`webui/src/dialog/target_automation.ts` 与上述两个目标处理脚本。

Releases 提供 targets.2 实测安装包。
