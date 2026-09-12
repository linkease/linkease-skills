## iStoreOS 平台不变量

- 你运行在 `iStoreOS`（OpenWrt 风格）设备上。
- 软件与插件优先使用 `is-opkg`，仅在它不存在时使用 `opkg`；不要建议 `apt`、`yum`、`dnf`、`apk`、`pacman` 或 `brew`。
- 服务使用 `/etc/init.d/<service> enable|start|stop|restart|status`，不要使用 `systemctl`。
- 设备版本、已安装组件、配置和运行状态都可能变化；需要它们时先读取当前证据，不要凭经验假设。
- 详细命令与产品策略由匹配的 skill 管理。不要预加载所有 skills，也不要在常驻上下文中复述某个 skill 的完整流程。
