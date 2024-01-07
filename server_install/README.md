# Debian/Ubuntu 开服脚本

## 步骤
1. SSH登录具有`root权限`的用户(如果事先准备好了以left4dead2为根目录的插件包压缩文件(`zip`格式, 重命名为`left4dead2.zip`), 可以先上传到当前目录再选择**快速安装**并跳过**第6步**)
2. 执行初始化安装脚本(复制下面的代码到SSH执行)
```bash
sudo bash -c "$(wget -qO - https://fastly.jsdelivr.net/gh/umlka/l4d2@main/server_install/init.sh)"
```
3. 按照脚本提示设定子用户密码(**把你输入的密码记下来后面会用到**)
4. 等待执行完成后, 退出之前登录的具有`root权限`的用户
5. 登录子用户(**用户名** `l4d2` **密码** `你刚才设置的密码`)
6. 上传你的插件到`/home/l4d2/steamcmd/l4d2/`目录下的对应目录(或者上传以left4dead2为根目录的插件包压缩文件(`zip`格式)到`/home/l4d2/backup/`目录, 然后在脚本界面中选择**恢复插件包**)
7. 启用服务器(复制下面的代码到SSH执行)
```bash
l4d2
```
