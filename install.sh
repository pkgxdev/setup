#!/bin/sh

set -e
set -o noglob

####################################################################### funcs
prepare() {
	if ! which tar >/dev/null 2>&1; then
		echo "tea: error: sorry. pls install tar :(" >&2
	fi

	if test -n "$VERBOSE"; then
		set -x
	fi

	if test $# -eq 0; then
		MODE="install"
	else
		MODE="exec"
	fi

	HW_TARGET=$(uname)/$(uname -m)

	ZZ=gz

	case $HW_TARGET in
	Darwin/arm64)
		ZZ=xz
		MIDFIX=darwin/aarch64;;
	Darwin/x86_64)
		ZZ=xz
		MIDFIX=darwin/x86-64;;
	Linux/arm64|Linux/aarch64)
		MIDFIX=linux/aarch64;;
	Linux/x86_64)
		MIDFIX=linux/x86-64;;
	*)
		echo "tea: error: (currently) unsupported OS or architecture ($HW_TARGET)" >&2
		echo "let’s talk about it: https://github.com/orgs/teaxyz/discussions" >&2
		exit 1;;
	esac

	# We support minimum OS version of 11 on Darwin
	if test "$(uname)" = "Darwin"; then
		MAJOR=$(sw_vers -productVersion | cut -d . -f 1)
		if test "$MAJOR" -lt 11; then
			echo "tea: error: we currently don't support macOS versions less than 11" >&2
			echo "let’s talk about it: https://github.com/orgs/teaxyz/discussions" >&2
			exit 1
		fi
	fi

	if test $ZZ = 'gz'; then
		if which base64 >/dev/null 2>&1; then
			BASE64_TARXZ="/Td6WFoAAATm1rRGAgAhARYAAAB0L+Wj4AX/AFNdADMb7AG6cMNAaNMVK8FvZMaza8QKKTQY6wZ3kG/F814lHE9ruhkFO5DAG7XNamN7JMHavgmbbLacr72NaAzgGUXOstqUaGb6kbp7jrkF+3aQT12CAAB8Uikc1gG8RwABb4AMAAAAeGbHwbHEZ/sCAAAAAARZWg=="
			if echo "$BASE64_TARXZ" | base64 -d | tar Jtf - >/dev/null 2>&1; then
				ZZ=xz
			fi
		elif which uudecode >/dev/null 2>&1; then
			TMPFILE=$(mktemp)
			cat >"$TMPFILE" <<-EOF
				begin 644 foo.tar.xz
				M_3=Z6%H\`\`\`3FUK1&\`@\`A\`18\`\`\`!T+^6CX\`7_\`%-=\`#,;[\`&Z<,-\`:-,5*\%O
				M9,:S:\0**308ZP9WD&_%\UXE'$]KNAD%.Y#\`&[7-:F-[),':O@F;;+:<K[V-
				M:\`S@&47.LMJ4:&;ZD;I[CKD%^W:03UV"\`\`!\4BD<U@&\1P\`!;X\`,\`\`\`\`>&;'
				-P;'\$9_L"\`\`\`\`\`\`196@\`\`
				\`
				end
				EOF
			if uudecode -p "$TMPFILE" | tar Jtf - >/dev/null 2>&1; then
				ZZ=xz
			fi
		fi
	fi

	case "$ZZ" in
	gz)
		TAR_FLAGS=xz # confusingly
		;;
	xz)
		TAR_FLAGS=xJ
		;;
	esac

	if test -n "$TEA_PREFIX" -a -f "$TEA_PREFIX/tea.xyz/v*/bin/tea"; then
		# if PREFIX is set but nothing is in it then we’ll do a full install
		# under the assumption the user is re-running this script on a broken install
		ALREADY_INSTALLED=1
	fi

	if test -z "$TEA_PREFIX"; then
		# use existing installation if found
		if which tea >/dev/null 2>&1; then
			TEA_PREFIX="$(tea --prefix --silent)"
			ALREADY_INSTALLED=1
		fi

		# we check again: in case the above failed for some reason
		if test -z "$TEA_PREFIX"; then
			if test "$MODE" = exec; then
				TEA_PREFIX="$(mktemp -dt tea-XXXXXX)"
			else
				TEA_PREFIX="$HOME/.tea"
			fi
		fi
	fi

	if test -z "$CURL"; then
		if which curl >/dev/null 2>&1; then
			CURL="curl -Ssf"
		elif test -f "$TEA_PREFIX/curl.se/v*/bin/curl"; then
			CURL="$TEA_PREFIX/curl.se/v*/bin/curl -Ssf"
		else
			# how they got here without curl: we dunno
			echo "tea: error: you need curl, or you can set \`\$CURL\`" >&2
			exit 1
		fi
	fi
}

gum_no_tty() {
	cmd="$1"
	while test "$1" != --; do
		shift
	done
	shift  # remove the --
	case "$cmd" in
	format|style)
		echo "$@";;
	confirm)
		if test -n "$YES"; then
			echo "tea: error: no tty detected, re-run with \`YES=1\` set" >&2
			return 1
		fi;;
	*)
		"$@";;
	esac
}

get_gum() {
	if test ! -t 1 -o "$GUM" = "0"; then
		GUM=gum_no_tty
	elif which gum >/dev/null 2>&1; then
		GUM=$(which gum)
	elif test -n "$ALREADY_INSTALLED"; then
		GUM="tea --silent +charm.sh/gum gum"
	elif test -f "$TEA_PREFIX/charm.sh/gum/v0.8.0/bin/gum"; then
		GUM="$TEA_PREFIX/charm.sh/gum/v0.8.0/bin/gum"
	else
		URL="https://dist.tea.xyz/charm.sh/gum/$MIDFIX/v0.8.0.tar.$ZZ"
		mkdir -p "$TEA_PREFIX"
		# shellcheck disable=SC2291
		printf "one moment, just steeping some leaves…"
		$CURL "$URL" | tar "$TAR_FLAGS" -C "$TEA_PREFIX"
		GUM="$TEA_PREFIX/charm.sh/gum/v0.8.0/bin/gum"
		printf "\r                                      "
	fi
}

gum() {
	case "$1" in
	confirm)
		if test -n "$YES"; then
			return
		fi;;
	spin)
		if test -n "$VERBOSE"; then
			gum_no_tty "$@"
			return
		fi;;
	esac

	$GUM "$@"
}

welcome() {
	gum format -- <<-EOMD
		# hi 👋 let’s set up tea

		* we’ll put it here: \`$TEA_PREFIX\`
		* everything tea installs goes there
		* (we won’t touch anything else)

		> docs https://github.com/teaxyz/cli#getting-started
		EOMD
	echo  #spacer

	if ! gum confirm "how about it?" --affirmative="install tea" --negative="cancel"
	then
			#0123456789012345678901234567890123456789012345678901234567890123456789012
		gum format -- <<-EOMD
			# kk, aborting

			btw \`tea\`’s just a standalone executable; you can run it anywhere; you \\
			don’t need to install it

			> check it https://github.com/teaxyz/cli
			EOMD
		echo  #spacer
		exit
	fi
}

get_tea_version() {
	# shellcheck disable=SC2086
	v="$(gum spin --show-output --title 'determing tea version' -- $CURL "https://dist.tea.xyz/tea.xyz/$MIDFIX/versions.txt" | tail -n1)"
	if test -z "$v"; then
		echo "failed to get latest tea version" >&2
		exit 1
	fi
}

fix_links() {
	OLDWD="$PWD"

	link() {
		if test -d "v$1" -a ! -L "v$1"; then
			echo "'v$1' is unexpectedly a directory" >&2
		else
			rm -f "v$1"
			ln -s "v$v" "v$1"
		fi
	}

	cd "$TEA_PREFIX"/tea.xyz
	link \*
	link "$(echo "$v" | cut -d. -f1)"
	link "$(echo "$v" | cut -d. -f1-2)"
	cd "$OLDWD"

}

install() {
	if test -n "$ALREADY_INSTALLED"; then
		TITLE="updating to tea@$v"
	else
		TITLE="fetching tea@$v"
	fi

	#NOTE using script instead of passing args to gum because
	# periodically the data didn’t pipe to tar causing it to error
	mkdir -p "$TEA_PREFIX/tea.xyz/tmp"
	SCRIPT="$TEA_PREFIX/tea.xyz/tmp/fetch-tea.sh"
	URL="https://dist.tea.xyz/tea.xyz/$MIDFIX/v$v.tar.$ZZ"
	echo "set -e; $CURL '$URL' | tar '$TAR_FLAGS' -C '$TEA_PREFIX'" > "$SCRIPT"
	gum spin --title "$TITLE" -- sh "$SCRIPT"

	fix_links

	if ! test "$MODE" = exec; then
		gum format -- "k, we installed \`$TEA_PREFIX/tea.xyz/v$v/bin/tea\`"
	fi

	VERSION="$(echo "$v" | cut -d. -f1)"
	tea="$TEA_PREFIX/tea.xyz/v$VERSION/bin/tea"

	echo  #spacer
}

check_path() {
	echo  #spacer

	gum format -- <<-EOMD
		# one second!
		tea’s not in your path!
		> *we may need to ask for your **root password*** (via \`sudo\` obv.)
		EOMD

	if gum confirm "create /usr/local/bin/tea?" --affirmative="make symlink" --negative="skip"
	then
		echo  #spacer
		sudo mkdir -p /usr/local/bin
		sudo ln -sf "$tea" /usr/local/bin/tea

		if ! which tea >/dev/null 2>&1
		then
			echo  #spacer
			gum format -- <<-EOMD
				> hmmm, \`/usr/local/bin\` isn’t in your path,
				> you’ll need to fix that yourself.
				> sorry 😞
				EOMD
		fi
	fi

	echo  #spacer
}

check_shell_magic() {
  sh="$(basename "$SHELL")"
	if test "$sh" = zsh; then
		gum format -- <<-EOMD
			# want magic?
			tea’s shell magic works via a one-line addition to your \`~/.zshrc\` \\
			it’s not required, **but we do recommend it**.

			> docs https://github.com/teaxyz/cli#usage-as-an-environment-manager
			EOMD

		if gum confirm 'magic?' --affirmative="add one-liner" --negative="skip"
		then
			cat <<-EOSH >> ~/.zshrc

				add-zsh-hook -Uz chpwd(){ source <(tea -Eds) }  #tea
				EOSH
		fi
	elif test "$sh" = "fish"; then
		gum format -- <<-EOMD
			# want magic?
			tea’s shell magic works via a simple hook function in fish \\
			it’s not required, **but we do recommend it**.

			> docs https://github.com/teaxyz/cli#usage-as-an-environment-manager
			EOMD

		if gum confirm 'magic?' --affirmative="add one-liner" --negative="skip"
		then
			"$SHELL" -c "function add_tea_environment --on-variable PWD; source <(teal -Eds|psub); end; funcsave add_tea_environment >/dev/null"
		fi
	else
		gum format -- <<-EOMD
			# we need your help 🙏

			our shell magic doesn’t support \`$sh\` yet, can you make a pull request?

			> https://github.com/teaxyz/cli/pulls
			EOMD
	fi

	echo  #spacer
}

########################################################################## go
prepare "$@"
get_gum
if test $MODE = install -a -z "$ALREADY_INSTALLED"; then
	welcome
fi
get_tea_version
if ! test -f "$TEA_PREFIX/tea.xyz/v$v/bin/tea"; then
	install
else
	fix_links  # be proactive in repairing the user installation just in case that's what they ran this for
	TEA_IS_CURRENT=1
	tea="$TEA_PREFIX/tea.xyz/v$v/bin/tea"
fi

if ! test -d "$TEA_PREFIX/tea.xyz/var/pantry"; then
	title="prefetching"
elif which git >/dev/null 2>&1; then
	title="syncing"
fi
gum spin --title "$title pantry" -- "$tea" --sync --dump

case $MODE in
install)
	if ! test -n "$ALREADY_INSTALLED"; then
		check_path
		check_shell_magic
		gum format -- <<-EOMD
			# you’re all set!
			try it out:
			EOMD
		gum style \
			--border=normal \
			--border-foreground 212 \
			--margin="1" \
			-- \
			"tea +gnu.org/wget wget -qO- tea.xyz/white-paper | tea +charm.sh/glow glow -"
	elif test -n "$TEA_IS_CURRENT"; then
		gum format -- <<-EOMD
			# the latest version of tea was already installed
			> $tea
			EOMD
	fi
	echo  #spacer
	;;
exec)
	if test -z "$ALREADY_INSTALLED" -a -t 1; then
		$tea "$@"

		echo  #spacer

		gum format <<-EOMD >&2
			> powered by [tea](https://tea.xyz); brew2 for equitable open-source
			EOMD

		echo  #spacer
	else
		# don’t hog resources
		exec $tea "$@"
	fi
	;;
esac
