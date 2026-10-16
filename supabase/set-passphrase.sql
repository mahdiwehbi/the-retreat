-- Sets the host passphrase for /host. Replace the text between the quotes, then Run.
update secrets set value = extensions.crypt('TYPE-YOUR-PASSPHRASE-HERE', extensions.gen_salt('bf')) where key = 'host_pin';
