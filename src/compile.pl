#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);

chdir $Bin;

unlink "MoneyMonster.$_" foreach qw(ex5 log);
unlink '/tmp/files.tbz2';

system qw(tar jcf /tmp/files.tbz2 .);
system qw(docker cp /tmp/files.tbz2 mt5:/tmp/files.tbz2);
system qw(docker exec mt5 chmod 777 /tmp/files.tbz2);

my $mt5     = '/config/.wine/drive_c/Program Files/MetaTrader 5';
my $mql5    = "$mt5/MQL5";
my $experts = "$mql5/Experts";
my $mm      = "$experts/MoneyMonster";
system qw(docker exec --user abc -w), $experts, qw(mt5 rm -fr MoneyMonster);
system qw(docker exec --user abc -w), $experts, qw(mt5 mkdir MoneyMonster);

system qw(docker exec --user abc -w), $mm, qw(mt5 bash -c), "tar jxf /tmp/files.tbz2 . 2>/dev/null";

system qw(docker exec --user abc -w), $mm, qw(mt5 wine compile.bat);
system qw(docker cp), "mt5:$mm/MoneyMonster.$_", "." foreach qw(ex5 log);

if (open my $log, '<', 'MoneyMonster.log') {
    while (<$log>) {
        s/\c@//g;
        s/\cM//g;
        s/\\xFF//g;
        s/\\xFE//g;
        $_ =~s{MQL5\\Experts\\MoneyMonster\\}{}g;
        print if /warning/ || /error/ || /Result/;
    }
}
