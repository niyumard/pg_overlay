# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_{7..9} )

inherit bash-completion-r1 check-reqs estack flag-o-matic llvm multiprocessing multilib-build python-any-r1 rust-toolchain toolchain-funcs

if [[ ${PV} = *beta* ]]; then
	betaver=${PV//*beta}
	BETA_SNAPSHOT="${betaver:0:4}-${betaver:4:2}-${betaver:6:2}"
	MY_P="rustc-beta"
	SLOT="beta/${PV}"
	SRC="${BETA_SNAPSHOT}/rustc-beta-src.tar.xz"
else
	ABI_VER="$(ver_cut 1-2)"
	SLOT="stable/${ABI_VER}"
	MY_P="rustc-${PV}"
	SRC="${MY_P}-src.tar.xz"
	KEYWORDS="~amd64 ~arm ~arm64 ~ppc64 ~x86"
fi

RUST_STAGE0_VERSION=${PV}
#RUST_STAGE0_VERSION="1.$(($(ver_cut 2) - 1)).0"

DESCRIPTION="Systems programming language from Mozilla"
HOMEPAGE="https://www.rust-lang.org/"

SRC_URI="
	https://static.rust-lang.org/dist/${SRC} -> rustc-${PV}-src.tar.xz
	!system-bootstrap? ( $(rust_all_arch_uris rust-${RUST_STAGE0_VERSION}) )
"

# keep in sync with llvm ebuild of the same version as bundled one.
ALL_LLVM_TARGETS=( AArch64 AMDGPU ARM AVR BPF Hexagon Lanai Mips MSP430
	NVPTX PowerPC RISCV Sparc SystemZ WebAssembly X86 XCore )
ALL_LLVM_TARGETS=( "${ALL_LLVM_TARGETS[@]/#/llvm_targets_}" )
LLVM_TARGET_USEDEPS=${ALL_LLVM_TARGETS[@]/%/?}

LICENSE="|| ( MIT Apache-2.0 ) BSD-1 BSD-2 BSD-4 UoI-NCSA"

IUSE="clippy cpu_flags_x86_sse2 debug doc libressl miri nightly parallel-compiler rls rustfmt +system-bootstrap system-llvm test wasm ${ALL_LLVM_TARGETS[*]}"

# Please keep the LLVM dependency block separate. Since LLVM is slotted,
# we need to *really* make sure we're not pulling more than one slot
# simultaneously.

# How to use it:
# 1. List all the working slots (with min versions) in ||, newest first.
# 2. Update the := to specify *max* version, e.g. < 12.
# 3. Specify LLVM_MAX_SLOT, e.g. 11.
LLVM_DEPEND="
	|| (
		sys-devel/llvm:11[${LLVM_TARGET_USEDEPS// /,}]
		sys-devel/llvm:10[${LLVM_TARGET_USEDEPS// /,}]
	)
	<sys-devel/llvm-12:=
	wasm? ( sys-devel/lld )
"
LLVM_MAX_SLOT=11

BOOTSTRAP_DEPEND="|| ( >=dev-lang/rust-1.$(($(ver_cut 2) - 1)) >=dev-lang/rust-bin-1.$(($(ver_cut 2) - 1)) )"

BDEPEND="${PYTHON_DEPS}
	app-eselect/eselect-rust
	|| (
		>=sys-devel/gcc-4.7
		>=sys-devel/clang-3.5
	)
	system-bootstrap? ( ${BOOTSTRAP_DEPEND} )
	!system-llvm? (
		dev-util/cmake
		dev-util/ninja
	)
"

# libgit2 should be at least same as bundled into libgit-sys #707746
DEPEND="
	>=dev-libs/libgit2-0.99:=
	net-libs/libssh2:=
	net-libs/http-parser:=
	net-misc/curl:=[http2,ssl]
	sys-libs/zlib:=
	!libressl? ( dev-libs/openssl:0= )
	libressl? ( dev-libs/libressl:0= )
	elibc_musl? ( sys-libs/libunwind:= )
	system-llvm? (
		${LLVM_DEPEND}
		>=sys-devel/clang-runtime-8.0[libcxx]
	)
"

RDEPEND="${DEPEND}
	app-eselect/eselect-rust
"

REQUIRED_USE="|| ( ${ALL_LLVM_TARGETS[*]} )
	miri? ( nightly )
	parallel-compiler? ( nightly )
	test? ( ${ALL_LLVM_TARGETS[*]} )
	wasm? ( llvm_targets_WebAssembly )
	x86? ( cpu_flags_x86_sse2 )
"

# we don't use cmake.eclass, but can get a warnings
CMAKE_WARN_UNUSED_CLI=no

QA_FLAGS_IGNORED="
	usr/lib/${PN}/${PV}/bin/.*
	usr/lib/${PN}/${PV}/lib/lib.*.so
	usr/lib/${PN}/${PV}/lib/rustlib/.*/bin/.*
	usr/lib/${PN}/${PV}/lib/rustlib/.*/lib/lib.*.so
"

QA_SONAME="
	usr/lib/${PN}/${PV}/lib/lib.*.so.*
	usr/lib/${PN}/${PV}/lib/rustlib/.*/lib/lib.*.so
"

# causes double bootstrap
RESTRICT="test"

PATCHES=(
	"${FILESDIR}"/1.46.0-don-t-create-prefix-at-time-of-check.patch
	"${FILESDIR}"/1.47.0-ignore-broken-and-non-applicable-tests.patch
	"${FILESDIR}"/gentoo-musl-target-specs.patch
)

S="${WORKDIR}/${MY_P}-src"

toml_usex() {
	usex "$1" true false
}

boostrap_rust_version_check() {
	# never call from pkg_pretend. eselect-rust may be not installed yet.
	[[ ${MERGE_TYPE} == binary ]] && return
	local rustc_wanted="$(ver_cut 1).$(($(ver_cut 2) - 1))"
	local rustc_version=( $(eselect --brief rust show 2>/dev/null) )
	rustc_version=${rustc_version[0]#rust-bin-}
	rustc_version=${rustc_version#rust-}

	[[ -z "${rustc_version}" ]] && die "Failed to determine rustc version!"

	if ver_test "${rustc_version}" -lt "${rustc_wanted}" ; then
		eerror "Rust >=${rustc_wanted} is required"
		eerror "please run \'eselect rust\' and set correct rust version"
		die
	else
		einfo "Using rust ${rustc_version} to build"
	fi
}

pre_build_checks() {
	local M=6144
	M=$(( $(usex clippy 128 0) + ${M} ))
	M=$(( $(usex miri 128 0) + ${M} ))
	M=$(( $(usex rls 512 0) + ${M} ))
	M=$(( $(usex rustfmt 256 0) + ${M} ))
	M=$(( $(usex system-llvm 0 2048) + ${M} ))
	M=$(( $(usex wasm 256 0) + ${M} ))
	M=$(( $(usex debug 15 10) * ${M} / 10 ))
	eshopts_push -s extglob
	if is-flagq '-g?(gdb)?([1-9])'; then
		M=$(( 15 * ${M} / 10 ))
	fi
	eshopts_pop
	M=$(( $(usex system-bootstrap 0 1024) + ${M} ))
	M=$(( $(usex doc 256 0) + ${M} ))
	CHECKREQS_DISK_BUILD=${M}M check-reqs_pkg_${EBUILD_PHASE}
}

pkg_pretend() {
	pre_build_checks
}

pkg_setup() {
	pre_build_checks
	python-any-r1_pkg_setup
	use system-bootstrap && boostrap_rust_version_check

	# required to link agains system libs, otherwise
	# crates use bundled sources and compile own static version
	export LIBGIT2_SYS_USE_PKG_CONFIG=1
	export LIBSSH2_SYS_USE_PKG_CONFIG=1
	export PKG_CONFIG_ALLOW_CROSS=1

	if use system-llvm; then
		llvm_pkg_setup

		local llvm_config="$(get_llvm_prefix "$LLVM_MAX_SLOT")/bin/llvm-config"

		export LLVM_LINK_SHARED=1
		export RUSTFLAGS="${RUSTFLAGS} -Lnative=$("${llvm_config}" --libdir)"
	fi
}

src_prepare() {
	if ! use system-bootstrap; then
		local rust_stage0_root="${WORKDIR}"/rust-stage0
		local rust_stage0="rust-${RUST_STAGE0_VERSION}-$(rust_abi)"

		"${WORKDIR}/${rust_stage0}"/install.sh --disable-ldconfig \
			--destdir="${rust_stage0_root}" --prefix=/ || die
	fi

	if use system-llvm; then
		rm -rf src/llvm-project/ || die
		rm -rf src/llvm/ || die
		sed -i.ffi -e '$a #[link(name = "ffi")] extern {}' src/librustc_llvm/lib.rs
	fi

	# Remove other unused vendored libraries 
	rm -rf vendor/jemalloc-sys/jemalloc/            
	rm -rf vendor/libz-sys/src/zlib/    
	rm -rf vendor/lzma-sys/xz-*/
	rm -rf vendor/openssl-src/openssl/
	rm -rf vendor/libgit2-sys/libgit2/
	rm -rf vendor/libssh2-sys/libssh2/

	# This only affects the transient rust-installer, but let it use our dynamic xz-libs
	sed -i.lzma -e '/LZMA_API_STATIC/d' src/bootstrap/tool.rs

	# The configure macro will modify some autoconf-related files, which upsets
	# cargo when it tries to verify checksums in those files.  If we just truncate
	# that file list, cargo won't have anything to complain about.
	find vendor -name .cargo-checksum.json \
		-exec sed -i.uncheck -e 's/"files":{[^}]*}/"files":{ }/' '{}' '+'

	# Sometimes Rust sources start with #![...] attributes, and "smart" editors think
	# it's a shebang and make them executable. Then brp-mangle-shebangs gets upset...
	find -name '*.rs' -type f -perm /111 -exec chmod -v -x '{}' '+'

	default
}

src_configure() {
	export RUSTFLAGS="-Ctarget-cpu=native -Copt-level=3"
	local rust_target="" rust_targets="" arch_cflags

	# Collect rust target names to compile standard libs for all ABIs.
	for v in $(multilib_get_enabled_abi_pairs); do
		rust_targets="${rust_targets},\"$(rust_abi $(get_abi_CHOST ${v##*.}))\""
	done
	if use wasm; then
		rust_targets="${rust_targets},\"wasm32-unknown-unknown\""
		if use system-llvm; then
			# un-hardcode rust-lld linker for this target
			# https://bugs.gentoo.org/715348
			sed -i '/linker:/ s/rust-lld/wasm-ld/' src/librustc_target/spec/wasm32_base.rs || die
		fi
	fi
	rust_targets="${rust_targets#,}"

	local tools="\"cargo\","
	if use clippy; then
		tools="\"clippy\",$tools"
	fi
	if use miri; then
		tools="\"miri\",$tools"
	fi
	if use rls; then
		tools="\"rls\",\"analysis\",\"src\",$tools"
	fi
	if use rustfmt; then
		tools="\"rustfmt\",$tools"
	fi

	local rust_stage0_root
	if use system-bootstrap; then
		rust_stage0_root="$(rustc --print sysroot)"
	else
		rust_stage0_root="${WORKDIR}"/rust-stage0
	fi

	rust_target="$(rust_abi)"

	cat <<- EOF > "${S}"/config.toml
		[llvm]
		optimize = $(toml_usex !debug)
		thin-lto = true
		release-debuginfo = $(toml_usex debug)
		assertions = $(toml_usex debug)
		ninja = true
		targets = "${LLVM_TARGETS// /;}"
		experimental-targets = ""
		link-jobs = $(makeopts_jobs)
		link-shared = true
		use-libcxx = true
		use-linker = "$(usex system-llvm lld)"

		[build]
		build = "${rust_target}"
		host = ["${rust_target}"]
		target = [${rust_targets}]
		cargo = "${rust_stage0_root}/bin/cargo"
		rustc = "${rust_stage0_root}/bin/rustc"
		docs = $(toml_usex doc)
		compiler-docs = $(toml_usex doc)
		submodules = true
		python = "${EPYTHON}"
		locked-deps = false
		vendor = true
		extended = true
		tools = [${tools}]
		verbose = 2
		sanitizers = false
		profiler = false
		cargo-native-static = false
		local-rebuild = false

		[install]
		prefix = "${EPREFIX}/usr/lib/${PN}/${PV}"
		sysconfdir = "etc"
		docdir = "share/doc/rust"
		bindir = "bin"
		libdir = "lib"
		mandir = "share/man"
		[rust]
		optimize = true
		debug = $(toml_usex debug)
		codegen-units-std = 1
		debug-assertions = $(toml_usex debug)
		debuginfo-level = 0
		debuginfo-level-rustc = 0
		backtrace = $(toml_usex debug)
		incremental = false
		default-linker = "$(tc-getCC)"
		parallel-compiler = $(toml_usex parallel-compiler)
		channel = "$(usex nightly nightly stable)"
		rpath = false
		verbose-tests = false
		optimize-tests = $(toml_usex !debug)
		codegen-tests = $(toml_usex debug)
		dist-src = $(toml_usex debug)
		lld = $(usex system-llvm false $(toml_usex wasm))
		backtrace-on-ice = true
		jemalloc = false

		[dist]
		src-tarball = false
	EOF

	for v in $(multilib_get_enabled_abi_pairs); do
		rust_target=$(rust_abi $(get_abi_CHOST ${v##*.}))
		arch_cflags="$(get_abi_CFLAGS ${v##*.})"

		cat <<- EOF >> "${S}"/config.env
			CFLAGS_${rust_target}=${arch_cflags}
		EOF

		cat <<- EOF >> "${S}"/config.toml
			[target.${rust_target}]
			cc = "$(tc-getBUILD_CC)"
			cxx = "$(tc-getBUILD_CXX)"
			linker = "$(tc-getCC)"
			ar = "$(tc-getAR)"
		EOF
		# librustc_target/spec/linux_musl_base.rs sets base.crt_static_default = true;
		if use elibc_musl; then
			cat <<- EOF >> "${S}"/config.toml
				crt-static = false
			EOF
		fi
		if use system-llvm; then
			cat <<- EOF >> "${S}"/config.toml
				llvm-config = "$(get_llvm_prefix "${LLVM_MAX_SLOT}")/bin/llvm-config"
			EOF
		fi
	done
	if use wasm; then
		cat <<- EOF >> "${S}"/config.toml
			[target.wasm32-unknown-unknown]
			linker = "$(usex system-llvm lld rust-lld)"
		EOF
	fi

	if [[ -n ${I_KNOW_WHAT_I_AM_DOING_CROSS} ]]; then # whitespace intentionally shifted below
	# experimental cross support
	# discussion: https://bugs.gentoo.org/679878
	# TODO: c*flags, clang, system-llvm, cargo.eclass target support
	# it would be much better if we could split out stdlib
	# complilation to separate ebuild and abuse CATEGORY to
	# just install to /usr/lib/rustlib/<target>

	# extra targets defined as a bash array
	# spec format:  <LLVM target>:<rust-target>:<CTARGET>
	# best place would be /etc/portage/env/dev-lang/rust
	# Example:
	# RUST_CROSS_TARGETS=(
	#	"AArch64:aarch64-unknown-linux-gnu:aarch64-unknown-linux-gnu"
	# )
	# no extra hand holding is done, no target transformations, all
	# values are passed as-is with just basic checks, so it's up to user to supply correct values
	# valid rust targets can be obtained with
	# 	rustc --print target-list
	# matching cross toolchain has to be installed
	# matching LLVM_TARGET has to be enabled for both rust and llvm (if using system one)
	# only gcc toolchains installed with crossdev are checked for now.

	# BUG: we can't pass host flags to cross compiler, so just filter for now
	# BUG: this should be more fine-grained.
	filter-flags '-mcpu=*' '-march=*' '-mtune=*'

	local cross_target_spec
	for cross_target_spec in "${RUST_CROSS_TARGETS[@]}";do
		# extracts first element form <LLVM target>:<rust-target>:<CTARGET>
		local cross_llvm_target="${cross_target_spec%%:*}"
		# extracts toolchain triples, <rust-target>:<CTARGET>
		local cross_triples="${cross_target_spec#*:}"
		# extracts first element after before : separator
		local cross_rust_target="${cross_triples%%:*}"
		# extracts last element after : separator
		local cross_toolchain="${cross_triples##*:}"
		use llvm_targets_${cross_llvm_target} || die "need llvm_targets_${cross_llvm_target} target enabled"
		command -v ${cross_toolchain}-gcc > /dev/null 2>&1 || die "need ${cross_toolchain} cross toolchain"

		cat <<- EOF >> "${S}"/config.toml
			[target.${cross_rust_target}]
			cc = "${cross_toolchain}-gcc"
			cxx = "${cross_toolchain}-g++"
			linker = "${cross_toolchain}-gcc"
			ar = "${cross_toolchain}-ar"
		EOF
		if use system-llvm; then
			cat <<- EOF >> "${S}"/config.toml
				llvm-config = "$(get_llvm_prefix "${LLVM_MAX_SLOT}")/bin/llvm-config"
			EOF
		fi

		# append cross target to "normal" target list
		# example 'target = ["powerpc64le-unknown-linux-gnu"]'
		# becomes 'target = ["powerpc64le-unknown-linux-gnu","aarch64-unknown-linux-gnu"]'

		rust_targets="${rust_targets},\"${cross_rust_target}\""
		sed -i "/^target = \[/ s#\[.*\]#\[${rust_targets}\]#" config.toml || die

		ewarn
		ewarn "Enabled ${cross_rust_target} rust target"
		ewarn "Using ${cross_toolchain} cross toolchain"
		ewarn
		if ! has_version -b 'sys-devel/binutils[multitarget]' ; then
			ewarn "'sys-devel/binutils[multitarget]' is not installed"
			ewarn "'strip' will be unable to strip cross libraries"
			ewarn "cross targets will be installed with full debug information"
			ewarn "enable 'multitarget' USE flag for binutils to be able to strip object files"
			ewarn
			ewarn "Alternatively llvm-strip can be used, it supports stripping any target"
			ewarn "define STRIP=\"llvm-strip\" to use it (experimental)"
			ewarn
		fi
	done
	fi # I_KNOW_WHAT_I_AM_DOING_CROSS

	einfo "Rust configured with the following settings:"
	cat "${S}"/config.toml || die
}

src_compile() {
	export RUSTFLAGS="-Ctarget-cpu=native -Copt-level=3"
	# we need \n IFS to have config.env with spaces loaded properly. #734018
	(
	IFS=$'\n'
	env $(cat "${S}"/config.env) RUST_BACKTRACE=1\
		"${EPYTHON}" ./x.py build -vv --config="${S}"/config.toml -j$(makeopts_jobs) || die
	)
}

src_test() {
	# https://rustc-dev-guide.rust-lang.org/tests/intro.html

	# those are basic and codegen tests.
	local tests=(
		codegen
		codegen-units
		compile-fail
		incremental
		mir-opt
		pretty
		run-make
	)

	# fails if llvm is not built with ALL targets.
	# and known to fail with system llvm sometimes.
	use system-llvm || tests+=( assembly )

	# fragile/expensive/less important tests
	# or tests that require extra builds
	# TODO: instead of skipping, just make some nonfatal.
	if [[ ${ERUST_RUN_EXTRA_TESTS:-no} != no ]]; then
		tests+=(
			rustdoc
			rustdoc-js
			rustdoc-js-std
			rustdoc-ui
			run-make-fulldeps
			ui
			ui-fulldeps
		)
	fi

	local i failed=()
	einfo "rust_src_test: enabled tests ${tests[@]/#/src/test/}"
	for i in "${tests[@]}"; do
		local t="src/test/${i}"
		einfo "rust_src_test: running ${t}"
		if ! (
				IFS=$'\n'
				env $(cat "${S}"/config.env) RUST_BACKTRACE=1 \
				"${EPYTHON}" ./x.py test -vv --config="${S}"/config.toml \
				-j$(makeopts_jobs) --no-doc --no-fail-fast "${t}"
			)
		then
				failed+=( "${t}" )
				eerror "rust_src_test: ${t} failed"
		fi
	done

	if [[ ${#failed[@]} -ne 0 ]]; then
		eerror "rust_src_test: failure summary: ${failed[@]}"
		die "aborting due to test failures"
	fi
}

src_install() {
	export RUSTFLAGS="-Ctarget-cpu=native -Copt-level=3"
	# https://github.com/rust-lang/rust/issues/77721
	# also 1.46.0-don-t-create-prefix-at-time-of-check.patch
	dodir "/usr/lib/${PN}/${PV}"
	(
	IFS=$'\n'
	env $(cat "${S}"/config.env) DESTDIR="${D}" \
		"${EPYTHON}" ./x.py install -vv --config="${S}"/config.toml || die
	)

	# bug #689562, #689160
	rm -v "${D}/usr/lib/${PN}/${PV}/etc/bash_completion.d/cargo" || die
	rmdir -v "${D}/usr/lib/${PN}/${PV}"/etc{/bash_completion.d,} || die
	dobashcomp build/tmp/dist/cargo-image/etc/bash_completion.d/cargo

	local symlinks=(
		rustc
		rustdoc
		rust-gdb
		rust-gdbgui
		rust-lldb
		cargo
	)

	use clippy && symlinks+=( clippy-driver cargo-clippy )
	use miri && symlinks+=( miri cargo-miri )
	use rls && symlinks+=( rls )
	use rustfmt && symlinks+=( rustfmt cargo-fmt )

	local i
	for i in "${symlinks[@]}"; do
		# we need realpath on /usr/bin/* symlink return version-appended binary path.
		# so /usr/bin/rustc should point to /usr/lib/rust/<ver>/bin/rustc-<ver>
		# need to fix eselect-rust to remove this hack.
		mv -v "${ED}/usr/lib/${PN}/${PV}/bin/${i}" "${ED}/usr/lib/${PN}/${PV}/bin/${i}-${PV}" || die
		ln -v "${ED}/usr/lib/${PN}/${PV}/bin/${i}-${PV}" "${ED}/usr/lib/${PN}/${PV}/bin/${i}" || die
		dosym "../lib/${PN}/${PV}/bin/${i}-${PV}" "/usr/bin/${i}-${PV}"
	done
	dosym "../../lib/${PN}/${PV}/share/doc" "/usr/share/doc/${P}"

	newenvd - "50${P}" <<-_EOF_
		LDPATH="${EPREFIX}/usr/lib/${PN}/${PV}/lib"
		MANPATH="${EPREFIX}/usr/lib/${PN}/${PV}/share/man"
		$(usex elibc_musl 'CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_RUSTFLAGS="-C target-feature=-crt-static"' '')
	_EOF_

	rm -rf "${ED}/usr/lib/${PN}/${PV}"/*.old || die
	rm -rf "${ED}/usr/lib/${PN}/${PV}/doc"/*.old || die

	# note: eselect-rust adds EROOT to all paths below
	cat <<-EOF > "${T}/provider-${P}"
		/usr/bin/cargo
		/usr/bin/rustdoc
		/usr/bin/rust-gdb
		/usr/bin/rust-gdbgui
		/usr/bin/rust-lldb
		/usr/share/doc/rust
	EOF
	if use clippy; then
		echo /usr/bin/clippy-driver >> "${T}/provider-${P}"
		echo /usr/bin/cargo-clippy >> "${T}/provider-${P}"
	fi
	if use miri; then
		echo /usr/bin/miri >> "${T}/provider-${P}"
		echo /usr/bin/cargo-miri >> "${T}/provider-${P}"
	fi
	if use rls; then
		echo /usr/bin/rls >> "${T}/provider-${P}"
	fi
	if use rustfmt; then
		echo /usr/bin/rustfmt >> "${T}/provider-${P}"
		echo /usr/bin/cargo-fmt >> "${T}/provider-${P}"
	fi

	insinto /etc/env.d/rust
	doins "${T}/provider-${P}"
}

pkg_postinst() {
	eselect rust update --if-unset

	elog "Rust installs a helper script for calling GDB and LLDB,"
	elog "for your convenience it is installed under /usr/bin/rust-{gdb,lldb}-${PV}."

	if has_version app-editors/emacs; then
		elog "install app-emacs/rust-mode to get emacs support for rust."
	fi

	if has_version app-editors/gvim || has_version app-editors/vim; then
		elog "install app-vim/rust-vim to get vim support for rust."
	fi
}

pkg_postrm() {
	eselect rust cleanup
}
