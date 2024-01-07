#!/usr/bin/env bash

NEW_USER="l4d2"
BASHRC_FILE="/home/${NEW_USER}/.bashrc"
SCRIPT_URL="https://fastly.jsdelivr.net/gh/umlka/l4d2@main/server_install/l4d2.sh"

function ubuntu() {
	echo -e "\e[92m安装依赖...\e[0m"
	sudo dpkg --add-architecture i386 && \
	sudo apt update && \
	case "${VERSION_ID}" in
		16.04|18.04|20.04)
			sudo apt -y install lib32gcc1 lib32stdc++6 lib32z1-dev curl screen zip unzip
		;;
		22.04)
			sudo apt -y install lib32gcc-s1 lib32stdc++6 lib32z1-dev curl screen zip unzip
		;;
		*)
			echo -e "\e[34m不支持的系统版本\e[0m \e[31m${VERSION_ID}\e[0m"
			exit 1
		;;
	esac

	if [ "${?}" -ne 0 ]; then
		echo -e "\e[31m依赖安装失败\e[0m"
		exit 1
	else
		echo -e "\e[92m依赖安装成功\e[0m"
	fi
}

function debian() {
	echo -e "\e[92m安装依赖...\e[0m"
	sudo dpkg --add-architecture i386 && \
	sudo apt update && \
	case "${VERSION_ID}" in
		9|10)
			sudo apt -y install lib32gcc1 lib32stdc++6 lib32z1-dev curl screen zip unzip
		;;
		11|12)
			sudo apt -y install lib32gcc-s1 lib32stdc++6 lib32z1-dev curl screen zip unzip
		;;
		*)
			echo -e "\e[34m不支持的系统版本\e[0m \e[31m${VERSION_ID}\e[0m"
			exit 1
		;;
	esac

	if [ "${?}"-ne 0 ]; then
		echo -e "\e[31m依赖安装失败\e[0m"
		exit 1
	else
		echo -e "\e[92m依赖安装成功\e[0m"
	fi
}

function install_dependencies() {
	source "/etc/os-release"
	case "${ID}" in
		ubuntu)
			ubuntu
		;;
		debian)
			debian
		;;
		*)
			echo -e "${ID}\e[34m不支持的操作系统\e[0m \e[31m${ID}\e[0m"
			exit 1
		;;
	esac
}

function create_user() {
	if getent passwd "${NEW_USER}" > /dev/null 2>&1; then
		echo -e "\e[34m用户\e[0m \e[31m${NEW_USER}\e[0m 已存在...\e[92m跳过\e[0m"
	else
		echo -e "\e[34m创建用户\e[0m \e[31m${NEW_USER}\e[0m"
		sudo useradd -d "/home/${NEW_USER}" -m -s "/bin/bash" -U "${NEW_USER}" && \
		while true; do
			echo -e -n "\e[33m请设置该用户密码\e[0m: "
			read -s PASSWORD1
			echo ""
			echo -e -n "\e[33m请再次输入该密码\e[0m: "
			read -s PASSWORD2
			echo ""
			if [ "${PASSWORD1}" == "${PASSWORD2}" ]; then
				break
			else
				echo -e "\e[31m两次输入的密码不同, 请重新输入\e[0m"
			fi
		done

		if ! echo "${NEW_USER}:${PASSWORD1}" | sudo chpasswd; then
			echo -e "\e[31m用户密码设置失败\e[0m"
			exit 1
		else
			echo -e "\e[92m用户密码设置成功\e[0m"
		fi
	fi
}

function install_server() {
	[ ! -d "/home/${NEW_USER}/backup" ] && mkdir "/home/${NEW_USER}/backup"

	echo -e -n "\e[33m是否进行一键式快速安装?(\e[34mY\e[0m/\e[34mn\e[0m) "
	if ! read -t 30 fast; then
		echo "n"
	fi

	if [ "${fast^^}" != "Y" ]; then
		action="1"
	else
		readarray -d $'\0' zipfiles < <(find ./ -maxdepth 1 -type f -iname "left4dead2*.zip" -printf '%T+ %f\0' | sort -nrz | cut -z -d ' ' -f 2-)
		if [ "${#zipfiles[@]}" -eq 0 ]; then
			echo -e "\e[34m快速安装前请先将插件包\e[31mzip压缩文件\e[0m(\e[34m文件名以\e[31mleft4dead2\e[0m\e[34m开头\e[0m, \e[34m如\e[0m\e[31mleft4dead2.zip\e[0m)\e[34m上传到\e[0m\e[31m$PWD\e[0m\e[34m目录\e[0m"
			echo -e -n "\e[33m上传完成后按回车键继续...\e[0m"
			read key
		fi

		readarray -d $'\0' zipfiles < <(find ./ -maxdepth 1 -type f -iname "left4dead2*.zip" -printf '%T+ %f\0' | sort -nrz | cut -z -d ' ' -f 2-)
		if [ "${#zipfiles[@]}" -gt 1 ]; then
			echo -e "\e[33m请选择恢复文件:\e[0m"
			for i in "${!zipfiles[@]}";do
				echo -e "\e[92m$i\e[0m.\e[34m${zipfiles[i]}\e[0m"
			done
			read -p "您的选择是: " res
		else
			res=0
		fi

		[ ! -z "${zipfiles[${res}]}" ] && [ -e "${zipfiles[${res}]}" ] && mv -f "${zipfiles[${res}]}" "/home/${NEW_USER}/backup/"

		echo -e "\e[33m请选择要预装的插件平台版本:\e[0m"
		echo -e "\e[92m1\e[0m.\e[34m稳定版(默认)\e[0m"
		echo -e "\e[92m2\e[0m.\e[34m测试版\e[0m"
		echo -e "\e[92m3\e[0m.\e[34m不预装(如果你上传的插件包内有插件平台请选择此选项)\e[0m"
		read -p "您的选择是: " plat
		case "${plat}" in
			1)
				action="1 8 -s 7 -0 2"
			;;
			2)
				action="1 8 -d 7 -0 2"
			;;
			*)
				action="1 8 -n 7 -0 2"
			;;
		esac
	fi

	sudo chown -R "${NEW_USER}:${NEW_USER}" "/home/${NEW_USER}/backup"
	sudo -i -H -u ${NEW_USER} bash <<-EOF
		echo -e "\e[34m开服脚本\e[0m 下载中 \e[92m${SCRIPT_URL}\e[0m"
		if ! curl --connect-timeout 10 -m 600 -fSLo "/home/${NEW_USER}/l4d2.sh" "${SCRIPT_URL}"; then
			echo -e "\e[34m开服脚本\e[0m \e[31m下载失败\e[0m"
			exit 1
		else
			echo -e "\e[34m开服脚本\e[0m \e[92m下载成功\e[0m"
			sed -i "/alias l4d2/d" "${BASHRC_FILE}"
			echo "alias l4d2='/home/${NEW_USER}/l4d2.sh'" >> "${BASHRC_FILE}"
			source "${BASHRC_FILE}"
			chmod u+x "/home/${NEW_USER}/l4d2.sh" && "/home/${NEW_USER}/l4d2.sh" "${action}"
		fi
	EOF
}

function main() {
	install_dependencies
	create_user
	install_server
}

main ${*}
