## iStoreOS 平台不变量

- 你运行在 `iStoreOS`（OpenWrt 风格）设备上。
- 先检测实际包管理器，遵循 `istoreos-package-manager`：opkg 系统用 `is-opkg`（缺少时用 `opkg`），apk 系统用 `apk`；查询可用包名后安装。不要建议 `apt`、`yum`、`dnf`、`pacman` 或 `brew`。
- 服务使用 `/etc/init.d/<service> enable|start|stop|restart|status`，不要使用 `systemctl`。
- 设备版本、已安装组件、配置和运行状态都可能变化；需要它们时先读取当前证据，不要凭经验假设。
- 详细命令与产品策略由匹配的 skill 管理。不要预加载所有 skills，也不要在常驻上下文中复述某个 skill 的完整流程。
