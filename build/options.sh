#!/bin/sh

# Copyright (c) 2021 Franco Fichtner <franco@opnsense.org>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

set -e

SELF=options

. ./common.sh

if [ -z "${PORTSLIST}" ]; then
	PORTSLIST=$(
cat ${CONFIGDIR}/ports.conf | while read PORT_ORIGIN PORT_IGNORE; do
	eval PORT_ORIGIN=${PORT_ORIGIN}
	if [ "$(echo ${PORT_ORIGIN} | colrm 2)" = "#" ]; then
		continue
	fi
	echo ${PORT_ORIGIN}
done
)
else
	PORTSLIST=$(
for PORT_ORIGIN in ${PORTSLIST}; do
	echo ${PORT_ORIGIN}
done
)
fi

git_branch ${PORTSDIR} ${PORTSBRANCH} PORTSBRANCH

setup_stage ${STAGEDIR}
sh ./make.conf.sh > ${STAGEDIR}/make.conf

for PORT in ${PORTSLIST}; do
	PORT=${PORT%%@*}
	MAKE="${ENV_FILTER} make -C ${PORTSDIR}/${PORT}"
	NAME=$(${MAKE} -v OPTIONS_NAME __MAKE_CONF=)
	DEFAULTS=$(${MAKE} -v PORT_OPTIONS __MAKE_CONF=)
	DEFINES=$(${MAKE} -v _REALLY_ALL_POSSIBLE_OPTIONS __MAKE_CONF=)

	SET=$(${MAKE} -v ${NAME}_SET __MAKE_CONF=${STAGEDIR}/make.conf)

	if [ -n "${SET}" ]; then
		for OPT in ${SET}; do
			for DEFAULT in ${DEFAULTS}; do
				if [ ${OPT} == EXAMPLES ]; then
					# ignore since defaults to off
					# but is required for acme.sh
					continue
				fi
				if [ ${OPT} == ${DEFAULT} ]; then
					echo "${PORT}: ${OPT} is set by default"
				fi
			done
		done
	fi

	UNSET=$(${MAKE} -v ${NAME}_UNSET __MAKE_CONF=${STAGEDIR}/make.conf)

	if [ -n "${UNSET}" ]; then
		for OPT in ${UNSET}; do
			FOUND=

			for DEFAULT in ${DEFAULTS}; do
				if [ ${OPT} = ${DEFAULT} ]; then
					FOUND=1
				fi
			done

			if [ -z "${FOUND}" ]; then
				echo "${PORT}: ${OPT} is unset by default"
			fi
		done
	fi

	if [ -n "${SET}${UNSET}" ]; then
		for OPT in ${SET} ${UNSET}; do
			FOUND=

			for DEFINE in ${DEFINES} ${DEFAULTS}; do
				if [ ${OPT} = ${DEFINE} ]; then
					FOUND=1
				fi
			done

			if [ -z "${FOUND}" ]; then
				echo "${PORT}: ${OPT} does not exist"
			fi
		done
	fi

	${MAKE} check-config __MAKE_CONF=${STAGEDIR}/make.conf
done
