#!/bin/bash

DEFAULT_DIR="l4d2"
DEFAULT_IP="0.0.0.0"
DEFAULT_PORT="27015"
DEFAULT_MAP="c2m1_highway"
DEFAULT_MODE="coop"
DEFAULT_CFG="server.cfg"
DEFAULT_TICK="66"
START_PARAMETERS="-strictportbind -nobreakpad -noassert -ip ${DEFAULT_IP} -port ${DEFAULT_PORT} +map ${DEFAULT_MAP} +mp_gamemode ${DEFAULT_MODE} +servercfgfile ${DEFAULT_CFG} -tickrate ${DEFAULT_TICK}"
STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
PLUGIN_VERSION=(-s -d -n)

function install_server() {
	trap 'rm -rf "${TMPDIR}"' EXIT
	TMPDIR=$(mktemp -d)
	if [ "${?}" -ne 0 ]; then
		echo -e "\e[31m临时目录\e[0m \e[31m创建失败\e[0m"
		exit 1
	fi

	[ ! -d "${HOME}/steamcmd" ] && mkdir "${HOME}/steamcmd"
	echo -e "\e[34msteamcmd\e[0m 下载中 \e[92m${STEAMCMD_URL}\e[0m"
	if ! curl --connect-timeout 10 -m 600 -fSLo "${TMPDIR}/steamcmd.tar.gz" "${STEAMCMD_URL}"; then
		echo -e "\e[34msteamcmd\e[0m \e[31m下载失败\e[0m"
		exit 1
	fi

	if ! tar -zxf "${TMPDIR}/steamcmd.tar.gz" -C "${HOME}/steamcmd"; then
		echo -e "\e[34msteamcmd.tar.gz\e[0m \e[31m解压失败\e[0m"
		exit 1
	fi

	echo -e "\e[34msteamcmd\e[0m \e[92m下载成功\e[0m"
	rm -rf "${TMPDIR}"

	rm -rf "${HOME}/steamcmd/${DEFAULT_DIR}"
	update_server
}

function start_server() {
	stop_server
	ln_lib32
	screen -dmS "${DEFAULT_DIR}" "${HOME}/steamcmd/${DEFAULT_DIR}/srcds_run" -game left4dead2 ${START_PARAMETERS}
	sleep 1s
	screen -wipe > /dev/null 2>&1
	if ! screen -ls | grep -E "[0-9]+\.${DEFAULT_DIR}" > /dev/null 2>&1; then
		echo -e "\e[34m${DEFAULT_DIR}\e[0m \e[31m启动失败\e[0m"
		echo -e "\e[31m请检查相关参数是否配置正确\e[0m"
		exit 1
	else
		echo -e "\e[34m${DEFAULT_DIR}\e[0m \e[92m启动成功\e[0m"
		echo -e "\e[34m输入\e[0m \e[92mscreen -r ${DEFAULT_DIR}\e[0m \e[34m进入控制台\e[0m"
		echo -e "\e[34m快捷键\e[0m \e[92mCtrl + A + D\e[0m \e[34m退出控制台\e[0m"
	fi
}

function stop_server() {
	screen -wipe > /dev/null 2>&1
	screen -ls | grep -Eo "[0-9]+\.${DEFAULT_DIR}" | xargs -i screen -S {} -X quit
}

function restart_server() {
	start_server
}

function update_server() {
	stop_server
	echo -e "\e[34mleft4dead2\e[0m 安装中 \e[92m...\e[0m"
	if ! "${HOME}/steamcmd/steamcmd.sh" +force_install_dir "${HOME}/steamcmd/${DEFAULT_DIR}" +login anonymous +app_update 222860 validate +quit; then
		echo -e "\e[34mleft4dead2\e[0m \e[31m安装失败\e[0m"
		exit 1
	else
		echo -e "\e[34mleft4dead2\e[0m \e[92m安装成功\e[0m"
	fi
}

function backup_plugin() {
	trap 'rm -rf "${BAKDIR}"' EXIT
	BAKDIR=$(mktemp -d)
	if [ "${?}" -ne 0 ]; then
		echo -e "\e[31m临时目录\e[0m \e[31m创建失败\e[0m"
		exit 1
	fi

	[ ! -d "${HOME}/backup" ] && mkdir "${HOME}/backup"
	readarray -d $'\0' zipfiles < <(find "${HOME}/backup/" -maxdepth 1 -type f -iname "*.zip" -printf '%T+ %f\0' | sort -nrz | cut -z -d ' ' -f 2-)
	if [ "${#zipfiles[@]}" -eq 0 ]; then
		echo -e "\e[31m备份目录下未发现备份文件\e[0m"
		echo -e "\e[34m请上传以\e[92mleft4dead2\e[0m\e[34m为根目录的备份文件\e[0m(\e[31mzip格式\e[0m)\e[34m到\e[0m\e[31m${HOME}/backup/\e[0m\e[34m目录\e[0m"
		exit 1
	fi

	if [ ! -z "${1}" ]; then
		res="${1}"
	elif [ "${#zipfiles[@]}" -gt 1 ]; then
		echo -e "\e[33m请选择备份模板:\e[0m"
		for i in "${!zipfiles[@]}";do
			echo -e "\e[92m$i\e[0m.\e[34m${zipfiles[i]}\e[0m"
		done
		read -p "您的选择是: " res
	else
		res=0
	fi

	if [ -z "${zipfiles[${res}]}" ] || [ ! -e "${HOME}/backup/${zipfiles[${res}]}" ]; then
		echo -e "\e[31m找不到对应的备份文件\e[0m"
		exit 1
	fi

	if ! unzip -qo "${HOME}/backup/${zipfiles[${res}]}" -d "${BAKDIR}"; then
		echo -e "\e[34m${zipfiles[${res}]}\e[0m \e[31m解压失败\e[0m"
		exit 1
	fi

	t=0
	y=0
	n=0
	nowtime=$(date +'%Y-%m-%d-%H-%M-%S-%N')
	mkdir "${BAKDIR}/left4dead2-${nowtime}"
	readarray -d $'\0' contents < <(find "${BAKDIR}/" -mindepth 1 -type d -printf '%P\0')
	for c in "${contents[@]}"; do
		readarray -d $'\0' files < <(find "${BAKDIR}/${c}/" -maxdepth 1 -type f -printf '%f\0')
		for f in "${files[@]}"; do
			((t++))
			if [ -e "${HOME}/steamcmd/${DEFAULT_DIR}/${c}/${f}" ]; then
				[ ! -d "${BAKDIR}/left4dead2-${nowtime}/${c}" ] && mkdir -p "${BAKDIR}/left4dead2-${nowtime}/${c}"
				if cp -f "${HOME}/steamcmd/${DEFAULT_DIR}/${c}/${f}" "${BAKDIR}/left4dead2-${nowtime}/${c}/${f}"; then
					((y++))
				else
					((n++))
				fi
			fi
		done
	done

	echo -e "\e[34m总数\e[0m\e[33m${t}\e[0m, \e[34m成功\e[0m\e[92m${y}\e[0m, \e[34m失败\e[0m\e[31m${n}\e[0m, \e[34m不存在\e[0m$((t-y-n))"
	if [ "${y}" -eq 0 ]; then
		echo -e "\e[31m备份创建失败\e[0m"
		exit 1
	else
		cd "${BAKDIR}/left4dead2-${nowtime}" && \
		zip -mqr "left4dead2-${nowtime}.zip" ./ && \
		mv -f "left4dead2-${nowtime}.zip" "${HOME}/backup/" && \
		echo -e "\e[34m备份\e[0m(\e[31m${HOME}/backup/left4dead2-${nowtime}.zip\e[0m)\e[92m创建成功\e[0m"
	fi

	rm -rf "${BAKDIR}"
}

function recover_plugin() {
	[ ! -d "${HOME}/backup" ] && mkdir "${HOME}/backup"
	readarray -d $'\0' zipfiles < <(find "${HOME}/backup/" -maxdepth 1 -type f -iname "*.zip" -printf '%T+ %f\0' | sort -nrz | cut -z -d ' ' -f 2-)
	if [ "${#zipfiles[@]}" -eq 0 ]; then
		echo -e "\e[31m备份目录下未发现备份文件\e[0m"
		echo -e "\e[34m请上传以\e[92mleft4dead2\e[0m\e[34m为根目录的备份文件\e[0m(\e[31mzip格式\e[0m)\e[34m到\e[0m\e[31m${HOME}/backup/\e[0m\e[34m目录\e[0m"
		exit 1
	fi

	if [ ! -z "${1}" ]; then
		res="${1}"
	elif [ "${#zipfiles[@]}" -gt 1 ]; then
		echo -e "\e[33m请选择恢复文件:\e[0m"
		for i in "${!zipfiles[@]}";do
			echo -e "\e[92m$i\e[0m.\e[34m${zipfiles[i]}\e[0m"
		done
		read -p "您的选择是: " res
	else
		res=0
	fi

	if [ -z "${zipfiles[${res}]}" ] || [ ! -e "${HOME}/backup/${zipfiles[${res}]}" ]; then
		echo -e "\e[31m找不到对应的备份文件\e[0m"
		exit 1
	fi

	if ! unzip -qo "${HOME}/backup/${zipfiles[${res}]}" -d "${HOME}/steamcmd/${DEFAULT_DIR}"; then
		echo -e "\e[31m备份恢复失败\e[0m"
		exit 1
	else
		echo -e "\e[34m备份\e[0m(\e[31m${HOME}/backup/${zipfiles[${res}]}\e[0m)\e[92m恢复成功\e[0m"
	fi
}

function mixed_platform() {
	trap 'rm -rf "${DLDIR}"' EXIT
	DLDIR=$(mktemp -d)
	if [ "${?}" -ne 0 ]; then
		echo -e "\e[31m临时目录\e[0m \e[31m创建失败\e[0m"
		exit 1
	fi

	if [ -z "${1}" ]; then
		echo -e "\e[33m请选择要安装的插件平台版本:\e[0m"
		echo -e "\e[92m1\e[0m.\e[34m稳定版(默认)\e[0m"
		echo -e "\e[92m2\e[0m.\e[34m测试版\e[0m"
		read -p "您的选择是: " res
		if [ "${res}" == "2" ]; then
			MMS_URL=$(curl -s "https://www.sourcemm.net/downloads.php?branch=dev" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
			SM_URL=$(curl -s "http://www.sourcemod.net/downloads.php?branch=dev" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
		else
			MMS_URL=$(curl -s "https://www.sourcemm.net/downloads.php?branch=stable" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
			SM_URL=$(curl -s "http://www.sourcemod.net/downloads.php?branch=stable" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
		fi
	else
		if [ "${1}" == "-d" ]; then
			MMS_URL=$(curl -s "https://www.sourcemm.net/downloads.php?branch=dev" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
			SM_URL=$(curl -s "http://www.sourcemod.net/downloads.php?branch=dev" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
		else
			MMS_URL=$(curl -s "https://www.sourcemm.net/downloads.php?branch=stable" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
			SM_URL=$(curl -s "http://www.sourcemod.net/downloads.php?branch=stable" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
		fi
	fi

	echo -e "\e[34mmmsource\e[0m 下载中 \e[92m${MMS_URL}\e[0m"
	if ! curl --connect-timeout 10 -m 600 -fSLo "${DLDIR}/mmsource-linux.tar.gz" "${MMS_URL}"; then
		echo -e "\e[34mmmsource\e[0m \e[31m下载失败\e[0m"
		exit 1
	fi

	if ! tar -zxf "${DLDIR}/mmsource-linux.tar.gz" -C "${HOME}/steamcmd/${DEFAULT_DIR}/left4dead2"; then
		echo -e "\e[34mmmsource-linux.tar.gz\e[0m \e[31m解压失败\e[0m"
		exit 1
	fi

	sed -i '/"file"/c\\t"file"\t"..\/left4dead2\/addons\/metamod\/bin\/server"' "${HOME}/steamcmd/${DEFAULT_DIR}/left4dead2/addons/metamod.vdf"
	sed -i '/"file"/c\\t"file"\t"..\/left4dead2\/addons\/metamod\/bin\/server"' "${HOME}/steamcmd/${DEFAULT_DIR}/left4dead2/addons/metamod_x64.vdf"
	echo -e "\e[34mmmsource\e[0m \e[92m下载成功\e[0m"

	echo -e "\e[34msourcemod\e[0m 下载中 \e[92m${SM_URL}\e[0m"
	if ! curl --connect-timeout 10 -m 600 -fSLo "${DLDIR}/sourcemod-linux.tar.gz" "${SM_URL}"; then
		echo -e "\e[34msourcemod\e[0m \e[31m下载失败\e[0m"
		exit 1
	fi

	if ! tar -zxf "${DLDIR}/sourcemod-linux.tar.gz" -C "${HOME}/steamcmd/${DEFAULT_DIR}/left4dead2"; then
		echo -e "\e[34msourcemod-linux.tar.gz\e[0m \e[31m解压失败\e[0m"
		exit 1
	fi

	rm -f "${HOME}/steamcmd/${DEFAULT_DIR}/left4dead2/addons/sourcemod/plugins/nextmap.smx"
	echo -e "\e[34msourcemod\e[0m \e[92m下载成功\e[0m"
	rm -rf "${DLDIR}"
}

function ln_lib32() {
	[ -e "/lib32/libgcc_s.so.1" ] && [ -e "${HOME}/steamcmd/${DEFAULT_DIR}/bin/libgcc_s.so.1" ] && ln -sf "/lib32/libgcc_s.so.1" "${HOME}/steamcmd/${DEFAULT_DIR}/bin/libgcc_s.so.1"
	[ -e "/lib32/libstdc++.so.6" ] && [ -e "${HOME}/steamcmd/${DEFAULT_DIR}/bin/libstdc++.so.6" ] && ln -sf "/lib32/libstdc++.so.6" "${HOME}/steamcmd/${DEFAULT_DIR}/bin/libstdc++.so.6"
}

function main() {
	if [ "${#}" -gt 0 ]; then
		while [ "${#}" -gt 0 ]; do
			case "${1}" in
				1|"install")
					shift
					install_server
				;;
				2|"start_server")
					shift
					start_server
				;;
				3|"stop_server")
					shift
					stop_server
				;;
				4|"restart")
					shift
					restart_server
				;;
				5|"update")
					shift
					update_server
				;;
				6|"backup")
					shift
					if ! echo "${1}" | grep -E "^-[0-9]+$" > /dev/null 2>&1; then
						backup_plugin
					else
						var="${1}"
						backup_plugin "${var:1}"
					fi
				;;
				7|"recover")
					shift
					if ! echo "${1}" | grep -E "^-[0-9]+$" > /dev/null 2>&1; then
						recover_plugin
					else
						var="${1}"
						recover_plugin "${var:1}"
					fi
				;;
				8|"mixed")
					shift
					if [[ "${PLUGIN_VERSION[@]}" =~ "${1}" ]]; then
						[ "${1}" != "-n" ] && mixed_platform "${1}"
					else
						mixed_platform
					fi
				;;
				*)
					shift
				;;
			esac
		done
	else
		echo -e "\e[33m请选择要执行的操作:\e[0m"
		echo -e "\e[92m1\e[0m.\e[34m安装服务器\e[0m"
		echo -e "\e[92m2\e[0m.\e[34m启动服务器\e[0m"
		echo -e "\e[92m3\e[0m.\e[34m停止服务器\e[0m"
		echo -e "\e[92m4\e[0m.\e[34m重启服务器\e[0m"
		echo -e "\e[92m5\e[0m.\e[34m更新服务器\e[0m"
		echo -e "\e[92m6\e[0m.\e[34m备份插件包\e[0m"
		echo -e "\e[92m7\e[0m.\e[34m恢复插件包\e[0m"
		echo -e "\e[92m8\e[0m.\e[34m安装插件平台\e[0m"
		read -p "您的选择是: " -a res
		for i in "${!res[@]}";do
			case "${res[i]}" in
				1)
					install_server
				;;
				2)
					start_server
				;;
				3)
					stop_server
				;;
				4)
					restart_server
				;;
				5)
					update_server
				;;
				6)
					if ! echo "${res[((i+1))]}" | grep -E "^-[0-9]+$" > /dev/null 2>&1; then
						backup_plugin
					else
						var="${res[((++i))]}"
						backup_plugin "${var:1}"
					fi
				;;
				7)
					if ! echo "${res[((i+1))]}" | grep -E "^-[0-9]+$" > /dev/null 2>&1; then
						recover_plugin
					else
						var="${res[((++i))]}"
						recover_plugin "${var:1}"
					fi
				;;
				8)
					if [[ "${PLUGIN_VERSION[@]}" =~ "${res[((i+1))]}" ]]; then
						var="${res[((++i))]}"
						[ "$var" != "-n" ] && mixed_platform "$var"
					else
						mixed_platform
					fi
				;;
			esac
		done
	fi
}

main ${*}
