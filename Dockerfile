FROM registry.opensuse.org/yast/sle-15/sp2/containers/yast-ruby
# Install journal for specific tests of this package
RUN zypper --non-interactive in yast2-journal
COPY . /usr/src/app

