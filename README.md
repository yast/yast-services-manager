About
=====
YaST Runlevel written in Ruby.
Still work in progress but already working.

Running
=======

    sudo cp src/runlevel-ruby.rb /usr/share/YaST2/clients/
    sudo cp src/SystemdTarget.rb /usr/share/YaST2/modules/
    sudo yast2 runlevel-ruby

Todo
====
- Makefile/Rakefile
- Test
- Packaging
- Use Classes/Struct and OOP instead of Hashes
- Documentation (probably yard)
