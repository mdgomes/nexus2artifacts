# nexus2artifacts

Bash script to migrate from Sonatype Nexus Repository Manager OSS to Azure DevOps Artifacts.

For better results follow these instructions:

* Place script in your /tmp folder, make it executable (chmod +x or just run it with sh/bash)
* Create a valid settings.xml file in ~/.m2 with the credentials to Azure DevOps (maven)
* Create a valid .npmrc file in ~/ with the credentials to Azure DevOps (npm)
* Edit the script, adjusting variables, and set the *deploy_artifacts* variable to *1* to actually process files

Additionally your maven blob folder must start with _"maven-"_ and your npm blob folders must start with _"npm-"_.

If you have proxies to other repositories, you can postfix them with _"-proxy"_ and enable the *skip_proxies* setting to ignore them.

*HINT:* If your blobs don't follow this format, just create a folder somewhere and symlink the blob folders to match the expected formats. Otherwise just edit away.

The script will try to validate that you have a sane environment before running and will try to install necessary packages if maven or npm is missing (requires root) but in the end it's up to you to ensure that the script can run.

*HINT:* Unless you have a very small repo, it's probably best to execute the script as such:

~~~~
$ cd /tmp
$ nohup ./nexus-exporter.sh &> exporter.log < /dev/null &
~~~~

This will execute the script in the background and will allow you to follow it's output by just tailing the log file, i.e.:

~~~~
$ tail -f /tmp/exporter.log
~~~~

Feel free to clone this repo or just tailor the script to your uses :)
