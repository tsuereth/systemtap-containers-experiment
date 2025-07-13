These build scripts and docker container definitions came from an experiment in rapidly deploying (and cleanly re-deploying) [systemtap](https://sourceware.org/systemtap/).

The experiment was successful, but its result turned out to be unnecessary `¯\_(ツ)_/¯` so no further enhancements or maintenance are expected.

The materials are preserved here for educational reference.

# Overview

As an administrator, I want to quickly install, run, uninstall, and reinstall a tool. And as a developer, I'm happy spending hours of hacking now to save a few minutes later. Hence: a containerized, reusable-ish runtime environment for systemtap!

*Why might I want to use systemtap?* ... like a "wiretap" for a Linux system, [systemtap](https://sourceware.org/systemtap/) can debug and/or monitor a running system using dynamic instrumentation "probes."

Once systemtap is properly installed and configured, a developer-administrator can rapidly iterate on that instrumentation to collect more and more-detailed diagnostics. The installation and configuration can be non-straightforward, though, so these materials aim to streamline that initial setup.

*What does "reusable-ish" mean?* ... since systemtap's runtime diagnostics rely on Linux kernel interfaces and type definitions - through header files and a build's debug symbol outputs - behavior is necessarily tied to a specific Linux kernel version and build. Changes to kernel APIs and build options may affect the compatibility of systemtap's instrumentation.

While the materials here include prepared systemtap runtime environments for some selected Linux distribution releases, they don't intend to provide comprehensive release support; rather, these examples intend to demonstrate patterns which can be easily extended to new environments by a user.

# Usage

**Requirements**:

1. A Linux host whose kernel headers and debug symbols are readily available.

This generally isn't a problem for popular distributions (like Debian and Ubuntu which provide `apt` packages for their own headers and symbols) but may be difficult in some situations, such as the [Windows Subsystem for Linux (WSL) kernel](https://github.com/microsoft/WSL2-Linux-Kernel) (which [doesn't provide those resources as easily](https://github.com/microsoft/WSL/issues/11557)).

Note that the "systemtap-runner" container definitions here *deliberately avoid* relying on lazy/dynamic retrieval of debug symbols through [debuginfod](https://wiki.debian.org/Debuginfod), opting to pre-install the kernel's debug symbols instead; this is a somewhat subjective choice, but is a significant benefit for systemtap to have those symbols immediately at startup.

2. A kernel version that's supported by systemtap itself.

Not only systemtap's probe behavior, but also its *code-generation behavior* depends on Linux kernel APIs at runtime. Yes, since systemtap generates (then compiles) instrumentation code dynamically, [a kernel-version compatibility conflict](https://stackoverflow.com/questions/75630436/systemtap-ubuntu-22-04-2-compile-error-static-declaration-of-proc-set-user-fo) may not be obvious until after systemtap has been installed.

[Systemtap's release notes](https://sourceware.org/systemtap/wiki/SystemTapReleases) indicate which kernel versions have been tested with each systemtap release; these details can help clarify whether or not your kernel version is known-good for a given systemtap version.

3. Docker installed and running.

The docker container definitions here require, well, Docker. Best practices and personal preferences for Docker setup will vary; consult [Docker's documentation](https://docs.docker.com/engine/install/) for recommendations based on your environment.

## For prepared runner environments

*NOT YET DOCUMENTED: docker pull and run instructions*

## For new runner environments

1. Build systemtap

Easy mode: `sudo ./systemtap-builder.sh`

In more detail:

- The shell script encodes a desired release version of systemtap. This is used by `systemtap-builder/Dockerfile` when performing a git checkout of systemtap sources.

- The script then `docker build`s this Docker container, which prepares a build environment for systemtap...

- And subsequently `docker run`s that container with a volume mountpoint into the host, so that its build output (the systemtap build/installation) will land on the host.

- Finally the script produces a small text file recording the install-prefix of this systemtap build (i.e. where systemtap expects to find its own installation files) and a compressed archive of the build's artifacts.

Those final outputs are used as inputs by the next (runner) step, through both steps' `BUILD_PREFIX_FILEPATH` and `BUILD_ARCHIVE_FILEPATH` variables.

2. Run systemtap with a tap script file

Easy mode: `sudo ./systemtap-runner-<LINUX_RELEASE>.sh <PATH/TO/TAPSCRIPT.stp>` depending on your host's Linux release version -- for example, `sudo ./systemtap-runner-debian-12.sh tcp_send_or_recv.stp`

In more detail:

- A release-specific shell script specifies the `RUNTIME_VERSION` variable before invoking `systemtap-runner-common.sh`

- That common runner script can accept manually-specified `BUILD_PREFIX_FILEPATH` and `BUILD_ARCHIVE_FILEPATH` variables, or will default to the same paths as the preceding builder script.

- An appropriate Dockerfile (based on `RUNTIME_VERSION`), and a copy of the systemtap build archive, are used to `docker build` a runtime environment for systemtap. That environment includes the [s6-overlay](https://github.com/just-containers/s6-overlay) init system, and the installation of dependency packages using `stap-prep` plus manual install commands.

- Finally the just-built container image is used with `docker run` and a read-only mount of the originally-provided tap script. The runner image's s6 init system invokes `stap` with that tap script filepath, and keeps `stap` running until the container is stopped.

# Q\&A

*"Why is this like this?" or, questions the author is asking himself afterward.*

## Why daemonize systemtap?

For debugging use-cases, it won't necessarily make sense to keep `stap` running persistently; you're probably going to have a probe open for a bit, check its results, then modify code and/or the probe and go again.

For *monitoring* however, i.e. to trigger a log event when particular kernel functions and arguments are seen, you'll want a long-running `stap` process to start at boot and keep on going in the background.

## Isn't containerizing systemtap kinda stupid?

Since a "runner" container is pretty host-specific (not very portable to other systems) *and* requires `--privileged` access to the host's running process details (isn't securely containing systemtap itself), yeah, a container for it is kinda stupid. :)

But! one particularly meaningful benefit of the "runner" container is encapsulating systemtap's runtime dependencies in a temporal filesystem. As those dependencies are somewhat significant - especially kernel debug symbols - and will be discarded/replaced if the kernel is updated, it's helpful to keep them in a container image which can itself be removed and replaced at a whim.

## Why build systemtap from source?

Story time:

Ubuntu 24.04 "noble" provides a package with (as of writing) [systemtap 5.0](https://packages.ubuntu.com/noble/systemtap). Ubuntu 24.04 also provides [GCC 13](https://packages.ubuntu.com/noble/gcc) as its default `gcc` version -- relevant because systemtap uses this default compiler for its runtime codegen.

A (debatable) bug in systemtap, [fixed in January 2024](https://sourceware.org/git/?p=systemtap.git;a=commitdiff;h=2604d135069f74cf5a223631cf92c9d0d818ef9c) - thus first included in systemtap's 5.1 release - was resulting in unexpected codegen behavior under newer GCC versions:

> GCC14 makes -Wmissing-prototypes defaultish on ... this broke the stap runtime autoconf\* business, bits of the runtime, bits of the translator.

(In fact, this "defaultish on" behavior seems to be true for GCC 13 as well.)

So systemtap 5.0's generated code, when compiled using GCC 13 and affected by this unintended compilation issue, doesn't correctly incorporate runtime compatibility checks such as [STAPCONF_MMAP_LOCK](https://sourceware.org/git/?p=systemtap.git;a=commitdiff;h=37066e2c3a9d9f48fc01b13ec0493b1c67551275) and *any* `stap` probe will encounter this runtime error (among many others):

```
In file included from /usr/share/systemtap/runtime/linux/access_process_vm.h:6,
                 from /usr/share/systemtap/runtime/linux/runtime.h:315,
                 from /usr/share/systemtap/runtime/runtime.h:26,
                 from /tmp/stap9xw9av/stap_eba171dbeb107825b7dcb29c70789601_1005_src.c:21:
/usr/share/systemtap/runtime/linux/access_process_vm.h: In function '__access_process_vm_':
/usr/share/systemtap/runtime/linux/stap_mmap_lock.h:10:43: error: 'struct mm_struct' has no member named 'mmap_sem'; did you mean 'mmap_base'?
   10 | #define mmap_read_lock(mm) down_read(&mm->mmap_sem)
```

In other words, the current Long Term Release version of Ubuntu (24.04) provides a default - outdated - version of systemtap and a default version of gcc which cannot work together.

... in *other* other words, it's generally more reliable to build a more-recent version of systemtap.

## Why patch out libboost_system?

Rewinding a bit to "isn't containerizing systemtap kinda stupid" and the benefit of encapsulating its runtime dependencies: a further benefit of *separately* containerizing the "builder" container is that systemtap's build-time dependencies don't have to be part of that environment too.

The upshot of keeping builder and runner dependencies separate is that, while runner dependencies are host-specific and must be customized for individual Linux releases, the builder dependencies are static and there's just one `systemtap-builder` container image.

Except... systemtap's configured link to `-lboost_system` unfortunately pulls along a *libboost version* dependency, from the builder into the runner. Differences between the builder environment and the runner environment mean it could be inconvenient to provide the same libboost version in both.

And it turns out that libboost_system *isn't used* by systemtap normally, only when [dyninst is being used for non-root instrumentation](https://developers.redhat.com/blog/2021/04/16/using-the-systemtap-dyninst-runtime-environment), per the [commit description of it](https://sourceware.org/git/?p=systemtap.git;a=commitdiff;h=891810c246d6de05a2df80c5b3e9f9aaa13231f7). Since this repository's systemtap-runner container is expected to run with root privileges, the dyninst use-case is irrelevant.

Removing the `-lboost_system` runtime dependency was the simplest way to avoid unwanted cross-pollination between these systemtap builder and runner environments.

# Maintenance

There probably won't be any; the author no longer needs this.

That said, there are many potential improvements to this approach for rapidly-initializing systemtap, including but not limited to:

- A simple helper/wrapper for selecting a host-appropriate "runner" i.e. to detect debian-12 versus ubuntu-24.04 in the host.

- An embellished "runner" environment which goes beyond systemtap's output vector, STDOUT, and can shuttle diagnostics along to a database or event bus of some kind. (This would likely require some kind of PID/process filtering in the probe itself, to prevent event transmissions from doubly-triggering systemtap's probes.)

- CPU architecture and libc awareness, so systemtap can be cross-compiled to (for example) ARM systems using musl instead of assuming x86_64 and glibc.
