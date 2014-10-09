# Gross, I know, but this can get pretty redic. without parallel.
# We are trading idempotence (which we lack anyhow, due to
# moving upstream gentoo-x86 target) for speed.
#
# Try three (or ${PROV_EMERGE_TRIES} times before we give up.
# In order to smoke out flakey parallel-build bugs (unfortunately
# they abound), make the third and final attempt with all
# parallel-build machinery deactivated.  If PROV_EMERGE_TRIES is
# defined, try that many times.
#
# If the first argument is a number, that will replace
# PROV_EMERGE_PARALLELISM and will not be passed along to emerge
#
# -gmt
#
try_emerge() {
	local prov_tries=${PROV_EMERGE_TRIES:-3}
	local prov_jobs=${PROV_EMERGE_PARALLELISM:-1}

	# n.b.: somehow /etc/hosts is locked up by docker
	# under certain conditions (bug?)
	[[ ${PROV_NO_OVERRIDE_CONFIG_PROTECT} ]] || \
		export CONFIG_PROTECT="-* /etc/hosts"

	# nb: somehow [[:isdigit:]]* is matching "-e"
	# here, do not use!
	if ( echo "$1" | grep -q '^[[0-9]]*$' ) ; then
		prov_jobs=$1
		shift
	fi
	local prov_makeopts="-j${prov_jobs}"
	local prov_parallel=
	if [[ ${prov_jobs} == 1 ]]; then
		prov_parallel=-
	fi
	prov_parallel=${prov_parallel}parallel-install
	local prov_parallel_args=(
		--jobs=${prov_jobs}
	)
	if [[ ${prov_jobs} != 1 ]]; then
		prov_parallel_args+=( --quiet-fail=y --fail-clean=y --keep-going=y )
	fi
	local prov_args=(
			--changed-use
			--nospinner
			--accept-properties=-interactive
			--backtrack=999
	)
	if [[ ${PROV_AUTOUNMASK} ]]; then
		echo "EXECUTING: FEATURES=notitles \\"
		echo "	CONFIG_PROTECT_MASK=/etc/portage \\"
		echo "	emerge \\"
		echo "	${prov_args[*]} \\"
		echo "	$* \\"
		echo "	--autounmask-write=y --nodeps --onlydeps"
		FEATURES=notitles CONFIG_PROTECT_MASK=/etc/portage \
			emerge \
			"${prov_args[@]}" \
			"$@" \
			--autounmask-write=y --nodeps --onlydeps
	fi

	local prov_success=1

	local my_prov_args=() my_prov_parallel=${prov_parallel} my_prov_makeopts="${prov_makeopts}"
	while [[ ${prov_success} -ne 0 && ${prov_tries} -gt 0 ]]; do
		if [[ ${prov_tries} -eq 1 ]]; then
			my_prov_parallel="-${prov_parallel#-}"
			my_prov_makeopts="-j1"
			my_prov_args=( "${prov_args[@]}" "$@" )
		else
			my_prov_args=( "${prov_parallel_args[@]}" "${prov_args[@]}" "$@" )
		fi
		echo "EXECUTING: MAKEOPTS=\"${my_prov_makeopts}\" \\"
		echo "	FEATURES=\"notitles ${my_prov_parallel}\" \\"
		echo "	emerge ${my_prov_args[*]}"
		MAKEOPTS="${my_prov_makeopts}" \
			FEATURES="notitles ${my_prov_parallel}" \
			emerge "${my_prov_args[@]}"
		prov_success=$?
		(( prov_tries-- ))
		if [[ ${prov_success} -ne 0 ]]; then
			echo
			if [[ ${prov_tries} -eq 0 ]]; then
				echo "==================================="
				echo "ERROR: emerge failed.  Giving up..."
				echo "==================================="
			else
				echo "=================================="
				echo "ERROR: emerge failed.  Retrying..."
				echo "=================================="
			fi
			echo
		elif [[ ! ${PROV_NO_OVERRIDE_CONFIG_PROTECT} ]]; then
			echo "=========================================="
			echo "emerge successful -- running etc-update..."
			echo "=========================================="
			etc-update --automode -5 || prov_success=$?
		fi
	done

	[[ ${PROV_NO_OVERRIDE_CONFIG_PROTECT} ]] || \
		unset CONFIG_PROTECT

	return ${prov_success}
}

hack_up_make_conf() {
	[[ -f /etc/portage/._make.conf.prov_ ]] && return 0
	cp /etc/portage/make.conf /etc/portage/old_upstream_make.conf
	mkdir /usr/portage_distfiles
	mkdir /usr/portage_packages
	cat >> /etc/portage/make.conf <<-EOF

		MAKEOPTS="-j${PROV_EMERGE_PARALLELISM:-1}"

		CFLAGS="\${CFLAGS} -mtune=core2"
		CXXFLAGS="\${CXXFLAGS} -mtune=core2"
		USE="\${USE} vim-syntax"
		USE="\${USE} bash-completion"

		DISTDIR="/usr/portage_distfiles"
		PKGDIR="/usr/portage_packages"

		EMERGE_DEFAULT_OPTS="\${EMERGE_DEFAULT_OPTS} --verbose"
		FEATURES="\${FEATURES} unmerge-orphans"
		FEATURES="\${FEATURES} parallel-fetch"
		FEATURES="\${FEATURES} sandbox"
		FEATURES="\${FEATURES} usersandbox"
		FEATURES="\${FEATURES} userpriv"
		FEATURES="\${FEATURES} usersync"
		FEATURES="\${FEATURES} userfetch"

		LINGUAS=""
		
		INPUT_DEVICES="evdev"

		RUBY_TARGETS="ruby19"
		PYTHON_TARGETS="python2_7 python3_3"
		PYTHON_SINGLE_TARGET="python2_7"
	EOF
	local x=$?
	[[ ${x} -eq 0 ]] && touch /etc/portage/._make.conf.prov_
	return ${x}
}

prov_locale() {
	local prov_locale=${PROV_LOCALE:-en_US}
	prov_locale=${prov_locale// /[[:space:]]}
	prov_locale=${prov_locale//./\.}

	if [[ $( cat /etc/locale.gen | \
			egrep '^[[:space:]]*'"${prov_locale}"'[[:space:]]*$' | \
			wc -l ) -eq 0 ]]; then
		sed -e '/^[[:space:]]*'"${prov_locale%%[[:space:]]*}"'\([[:space:]]\|$\)/d' \
			-i /etc/locale.gen
		echo "${PROV_LOCALE}" >> /etc/locale.gen
	fi
	echo
	echo '--- Here is the new /etc/locale.gen ---'
	cat /etc/locale.gen
	echo
	echo '--- Generating... ---'
	locale-gen || return $?
	eselect locale set "${PROV_LOCALE%% *}" || return $?
	etc-update --automode -5 || return $?
	env-update || return $?
}

