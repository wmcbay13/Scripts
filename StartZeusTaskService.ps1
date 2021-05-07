$s = new-pssession -computerName bsztask01,bsztask02,bsztask03,bsztask04,bsztask05,bsztask06,bsztask07,bsztask08,bsztask09,bsztask10
invoke-command -session $s {sc.exe start ZeusTaskService }

