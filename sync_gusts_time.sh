#!/bin/bash
{
	cd || exit 1

	readonly USER_BASH_PROFILE_PATH="${HOME}/.bash_profile"
	readonly USER_PROFILE_PATH="${HOME}/.profile"

	if [ -f "${USER_BASH_PROFILE_PATH}" ]; then
		source "${USER_BASH_PROFILE_PATH}" >/dev/null 2>&1 || exit 200
	elif [ -f "${USER_PROFILE_PATH}" ]; then
		source "${USER_PROFILE_PATH}" >/dev/null 2>&1 || exit 210
	else
		exit 220
	fi

	#ロックファイルのパス
	readonly _lockfile="/tmp/${MY_NAME}.lock"

	function log_and_exit() {
		local -r YMD_VAL=$(date +%Y%m%d%H%M%S)
		echo "${YMD_VAL}_${1}_${3}" >>"${2}"
		exit "${3}"
	}

	readonly LOGDIR="/var/log/sync-guests-time-log"
	readonly LOGFILE="${LOGDIR}/$(date +%Y%m%d%H%M%S)_sync-guests-time.log"
	mkdir -p "${LOGDIR}" && chmod 755 "${LOGDIR}" || exit 100

	echo "$(date +%Y%m%d%H%M%S)_開始します。" >>"${LOGFILE}"

	#ロックファイル生成。
	echo "$(date +%Y%m%d%H%M%S)_ロックファイル生成。" >>"${LOGFILE}"
	exec 9>"${_lockfile}"
	if ! flock -n 9; then
		log_and_exit "Cannot run multiple instance." 110
	fi

	# ファイル更新日時が5000日を越えたログファイルを削除
	echo "$(date +%Y%m%d%H%M%S)_旧ログ削除。" >>"${LOGFILE}"
	readonly PARAM_DATE_NUM=5000
	find "${LOGDIR}" -name "*.log" -type f -mtime +"${PARAM_DATE_NUM}" -exec rm -f {} \;

	# VM一覧を取得（エラーハンドリング付き）
	readonly VM_RUNNING_STATE='running'
	VM_LIST_SRC_TEMP=$(
		export LANG=C
		virsh list --all | grep -v "^$"
	) || {
		log_and_exit "FAILED TO GET VM LIST. CHECK IF LIBVIRT IS RUNNING AND YOU HAVE PROPER PERMISSIONS." 10
	}
	readonly VM_LIST_SRC="${VM_LIST_SRC_TEMP}"

	# VMが起動しているか確認し、起動しているVMのリストを作成
	readonly VM_RUNNING_LIST=$(echo "${VM_LIST_SRC}" | grep "${VM_RUNNING_STATE}" | grep -v "^$")
	readonly VM_RUNNING_COUNT=$(echo "${VM_RUNNING_LIST}" | grep -v "^$" | wc -l)
	
	# 起動しているVMの名前を抽出し、重複を排除してソート
	readonly VM_LIST=$(echo "${VM_RUNNING_LIST}" | grep -v "^$" | awk '{print $2}' | sort | uniq)

	if [ 0 -eq "${VM_RUNNING_COUNT}" ]; then
		echo "${VM_LIST_SRC_TEMP}" >>"${LOGFILE}"
		log_and_exit "VM IS NOT RUNNING. EXIT." 1
	fi
	readonly SORTED_VM_LIST="${VM_LIST}"

	for vm in ${SORTED_VM_LIST}; do
		echo "Syncing ${vm}..." >>"${LOGFILE}" 2>&1
		virsh domtime "${vm}" --sync >>"${LOGFILE}" 2>&1
	done

	log_and_exit "正常終了します。" "${LOGFILE}" 0
}
