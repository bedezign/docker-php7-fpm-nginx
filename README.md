# PHP7 - FPM - nginx - supervisord

One of the images I use locally to develop. Based on a combo of "stuff out there".
It's like a vagrant image, as it serves more than a simple purpose (and not really of the "docker-mindset" that one container has one responsibility), 
but it makes my life easier and has the advantage of being scripted and easy to maintain.

Use it if you like it, don't if you don't.

## supervisord

Both nginx and fpm are monitored by supervisord, allowing you to make changes to the config files within the container and rebooting them without the container terminating.

