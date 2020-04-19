#!/bin/bash

# Please note, you will have to have a valid settings.xml file (in ~/.m2) 
# and a valid .npmrc (in your home folder) for this script to actually publish stuff to DevOps
# 
# Additionally your maven blob folder must start with maven- 
# and your npm blob folders must start with npm-
# 
# If you have proxies to other repositories, you can postfix them with -proxy and enable the
# skip_proxies setting to ignore them.
# Hint: if your blobs don't follow this format, just create a folder somewhere and symlink 
# the blob folders to match the expected formats. Otherwise just edit away.

# Nexus Blobs directory
root_dir="/opt/sonatype/sonatype-work/nexus3/blobs"
# Where to store temporary work
export_dir="/tmp/nexus-backup"
# Virtual Maven Repository
repo_dir="${export_dir}/repository"

# Edit this to match the correct Artifacts Feed
# Check the Artifacts Feeds Connect To page for more information
organization_id="organization";
repo_id="repo";
project_id="project";
repo_url="https://pkgs.dev.azure.com/${organization_id}/${project_id}/_packaging/${repo_id}/maven/v1"
npm_url="https://pkgs.dev.azure.com/${organization_id}/${project_id}/_packaging/${repo_id}/npm/registry/"

# If you are using publishConfig with a repository on your npm packages put here the original repo
nexus_npm_url="https://someurl/nexus/repository/npm-telco-release";

# Set to 1 to deploy to Artifacts
deploy_artifacts=0;
# set to 1 to generate a SQL file with existing packages
generate_sql=0;
# set to 1 to generate a CSV file with existing packages
generate_csv=1;
# set to 1 to generate a virtual repository which can be used to deploy javadoc and sources
generate_virtual_repo=1;
# set to 1 to skip any repository that ends with proxy
skip_proxies=1;
# set to 1 to skip deploying maven javadoc files
skip_deploy_javadoc=1;
# set to 1 to skip deploying maven sources files
skip_deploy_sources=1;

# For better results, enable generate virtual repo and disable deploying javadoc and source files.

# Some tests
is_alpine=0;
is_debian=0;
is_rhel=0;

# test if alpine
if [[ -f /etc/alpine_release ]]; then
	is_alpine=1;
fi
# test if debian/ubuntu
if [[ ( -f /etc/debian_version ) || ( -f /etc/lsb_release ) ]]; then
	is_debian=1;
fi
# test if rhel/fedora/centos
if [[ ( -f /etc/redhat-release ) || ( -f /etc/fedora-release ) ]]; then
	is_rhel=1;
fi

print_ok() {
	echo -e "[ \e[32mOK\e[0m ]";
}

print_warn() {
	echo -e "[\e[33mWARN\e[0m]";
}

print_ignr() {
	echo -e "[\e[33mIGNR\e[0m]";
}

print_skip() {
	echo -e "[\e[33mSKIP\e[0m]";
}

print_fail() {
	echo -e "[\e[31mFAIL\e[0m]";
}

ensure_pkgs() {
	echo -ne "\tChecking for Maven ... ";
	mvn --version &> /dev/null
	if [[ $? == 0 ]]; then
		print_ok;
	else
		print_fail;
		if [[ $is_alpine == 1 ]]; then
			echo -e "\tInstalling maven (# apk add maven) ... "
			apk add maven &> /dev/null;
			if [[ $? == 0 ]]; then
				print_ok;
			else
				print_fail;
				exit 1;
			fi
		elif [[ $is_debian == 1 ]]; then
			echo -e "\tInstalling maven (# apt install maven) ... "
			apt install maven &> /dev/null;
			if [[ $? == 0 ]]; then
				print_ok;
			else
				print_fail;
				exit 1;
			fi
		elif [[ $is_rhel == 1 ]]; then
			echo -e "\tInstalling maven (# yum install apache-maven) ... "
			yum install apache-maven &> /dev/null;
			if [[ $? == 0 ]]; then
				print_ok;
			else
				print_fail;
				exit 1;
			fi
		else
			exit 1;
		fi
	fi
	echo -ne "\tChecking for NPM ... ";
	npm --version &> /dev/null
	if [[ $? == 0 ]]; then
		print_ok;
	else
		print_fail;
		if [[ $is_alpine == 1 ]]; then
			echo -e "\tInstalling npm (# apk add npm) ... "
			apk add npm &> /dev/null;
			if [[ $? == 0 ]]; then
				print_ok;
			else
				print_fail;
				exit 1;
			fi
		elif [[ $is_debian == 1 ]]; then
			echo -e "\tInstalling maven (# apt install npm) ... "
			apt install npm &> /dev/null;
			if [[ $? == 0 ]]; then
				print_ok;
			else
				print_fail;
				exit 1;
			fi
		elif [[ $is_rhel == 1 ]]; then
			echo -e "\tInstalling maven (# yum install nodejs) ... "
			yum install nodejs &> /dev/null;
			if [[ $? == 0 ]]; then
				print_ok;
			else
				print_fail;
				exit 1;
			fi
		else
			exit 1;
		fi
	fi
}

# ensure m2 folder
ensure_m2() {
	echo -ne "\tChecking for local m2 folder ... "
	if [[ -d ~/.m2 ]]; then
		print_ok;
	else
		print_fail;
		echo -ne "\tCreating m2 folder (# mkdir ~/.m2) ... "
		mkdir ~/.m2 &> /dev/null
		if [[ $? == 0 ]]; then
			print_ok;
		else
			print_fail;
			exit 1;
		fi
	fi
}

ensure_settings() {
	echo -ne "\tChecking for settings.xml in ~/.m2 ... ";
	if [[ -f ~/.m2/settings.xml ]]; then
		print_ok;
	else
		if [[ $deploy_artifacts == 0 ]]; then
			print_warn;
			echo -e "\tPlease create a valid settings.xml file in the ~/.m2 folder!";
		else
			print_fail;
			echo -e "\tPlease create a valid settings.xml file in the ~/.m2 folder!";
			exit 1;
		fi
	fi
}

ensure_npmrc() {
	echo -ne "\tChecking for .npmrc in ~/ ... ";
	if [[ -f ~/.npmrc ]]; then
		print_ok;
	else
		if [[ $deploy_artifacts == 0 ]]; then
			print_warn;
			echo -e "\tPlease create a valid .npmrc file in the ~/ folder!";
		else
			print_fail;
			echo -e "\tPlease create a valid .npmrc file in the ~/ folder!";
			exit 1;
		fi
	fi
}

print_settings() {
	echo "Nexus exporter settings..."
	echo
	echo -e "\tNexus blob directory: ${root_dir}"
	echo -e "\tExport directory: ${export_dir}"
	echo -e "\tVirtual maven repository directory: ${repo_dir}";
	echo
	echo -e "\tArtifacts Feed identifier: ${repo_id}"
	echo -e "\tArtifacts Maven URL: ${repo_url}";
	echo -e "\tArtifacts NPM URL: ${npm_url}";
	echo -e "\tNexus NPM URL: ${nexus_npm_url}";
	echo
	echo -e "\tDeploy to Artifacts: ${deploy_artifacts}";
	echo -e "\tGenerate SQL: ${generate_sql}";
	echo -e "\tGenerate CSV: ${generate_csv}";
	echo
	echo -e "\tSkip proxy repositories: ${skip_proxies}";
	echo -e "\tSkip deploying maven javadoc packages: ${skip_deploy_javadoc}";
	echo -e "\tSkip deploying maven sources packages: ${skip_deploy_sources}";
	echo
	echo "Validating environment..."
	echo
}

print_settings;
ensure_pkgs;
ensure_m2;
ensure_settings;
ensure_npmrc;

echo

mkdir -p ${repo_dir};

generate_vrepo() {
	if [[ ${generate_virtual_repo} == 0 ]]; then
		return;
	fi
	echo "Generating virtual maven repository...";

	for dir in ${root_dir}/*; do
		dirname=$(basename $dir);
		if [[ ( $skip_proxies == 1 ) && ( ${dirname##*-} == "proxy" ) ]]; then
			continue;
		fi
		if [[ ${dirname:0:5} != "maven" ]]; then
			continue;
		fi
		backup_dir="${repo_dir}/${dirname}"
		mkdir -p ${backup_dir};
		echo -e "\tProcessing \"${dirname}\"...";
		new_dir="${dir}/content";
		for vol in ${root_dir}/${dirname}/content/vol-*; do
			volname=$(basename $vol);
			if [[ ( "$volname" == "tmp" ) || ( "$volname" == "vol-*" ) ]]; then
				continue;
			fi
			echo -e "\t\tProcessing volume \"${volname}\"...";
			for chapter in ${vol}/chap-*; do
				chaptername=$(basename $chapter);
				if [[ "$chaptername" == "chap-*" ]]; then
					continue;
				fi
				# process properties files
				for file in ${chapter}/*.properties; do
					fname=$(basename $file);
					fname=${fname%%.*};
					deleted=0;
					sha="";
					size=0;
					creation_time=0;
					repo_name="";
					content_type="";
					blob_name="";
					group_id="";
					artifact_id="";
					version="";
					qualifier="";
					packaging="";
					type="";
					is_metadata=0;
					# process atribute files
					while IFS= read -r line; do
						if [[ $line == deleted\=* ]]; then
							deleted=${line##deleted\=}
							if [[ $deleted == true ]]; then
								deleted=1;
							else
								deleted=0;
							fi
						fi
						if [[ $line == size* ]]; then
							size=${line##size\=}
						fi
						if [[ $line == sha* ]]; then
							sha=${line#sha1\=}
						fi
						if [[ $line == creationTime* ]]; then
							creation_time=${line##creationTime\=}
						fi
						if [[ $line == \@BlobStore\.content\-type* ]]; then
							content_type=${line##\@BlobStore\.content\-type\=}
						fi
						if [[ $line == \@BlobStore\.blob\-name* ]]; then
							blob_name=${line##\@BlobStore\.blob\-name\=};
							# some extra handling to figure out stuff
							last_segment=${blob_name##*/};
							if [[ ( $last_segment == "maven-metadata.xml" ) || ( $last_segment == "archetype-catalog.xml" ) ]]; then
								is_metadata=1;
							fi
							#now replace the last segment within the line so that we can extract the version
							verstr=${blob_name/\/${last_segment}/};
							version=${verstr##*/};
							artstr=${verstr/\/${version}/};
							if [[ ${version} == \- ]]; then
								aux=${last_segment##*-};
								version=${aux%\.*};
							fi
							# handle now artifactId
							artifact_id=${artstr##*/};
							# handle groupId
							groupstr=${artstr/\/${artifact_id}/};
							if [[ ${groupstr} != ${artifact_id} ]]; then
								group_id=${groupstr//\//\.};
							fi
							# handle qualifier
							aux=${last_segment/${artifact_id}-${version}/};
							type=${aux##*.};
							packaging=${aux#*.};
							if [[ ${aux:0:1} == "-" ]]; then
								aux=${aux##*-};
								aux=${aux%%.*};
								qualifier=$aux;
							fi
						fi
						if [[ $line == \@Bucket\.repo\-name* ]]; then
							repo_name=${line##\@Bucket\.repo\-name\=}
						fi
					done < "$file";

					if [[ ( $deleted == 1 ) || ( ${type} == md5 ) || ( ${type} == sha1 ) || ( ${is_metadata} == 1 ) ]]; then
						continue;
					fi

					# generate virtual repo
					bin_file=${file/.properties/.bytes};
					skip_deploy=0;
					artifact_type="maven";
					vdir="${backup_dir}/${group_id}/${artifact_id}/${version}";
					mkdir -p ${vdir}
					vfile="${artifact_id}-${version}";
					echo -ne "\t\t\tLinking ${artifact_type} blob \"${bin_file}\" to virtual artifact (${group_id}/${artifact_id}-${version}";
					if [[ ${#qualifier} > 0 ]]; then
						echo -ne "-${qualifier}";
						vfile="${vfile}-${qualifier}";
					fi
					echo -ne ".${packaging}) ... ";
					vfile="${vfile}.${packaging}";
					ln -sf ${bin_file} "${vdir}/${vfile}";
					if [[ $? == 0 ]]; then
						print_ok;
					else
						print_fail;
					fi
				done
			done
		done
	done
}

process_blobs() {
	echo "Processing blobs..."

	for dir in ${root_dir}/*; do
		dirname=$(basename $dir);
		if [[ ( $skip_proxies == 1 ) && ( ${dirname##*-} == "proxy" ) ]]; then
			continue;
		fi
		vrepo_dir="${repo_dir}/${dirname}"
		backup_dir="${export_dir}/${dirname}"
		export_file="${export_dir}/${dirname}.sql"
		csv_file="${export_dir}/${dirname}.csv"
		if [[ $generate_csv == 1 ]]; then
			echo "sha1,size,deleted,creationTime,blobName,groupId,artifactId,version,type,qualifier,contentType,repoName,store,volume,chapter" > ${csv_file};
		if
		mkdir -p ${backup_dir};
		rm ${export_file} &> /dev/null;
		echo -e "\tProcessing \"${dirname}\"...";
		new_dir="${dir}/content";
		for vol in ${root_dir}/${dirname}/content/vol-*; do
			volname=$(basename $vol);
			if [[ ( "$volname" == "tmp" ) || ( "$volname" == "vol-*" ) ]]; then
				continue;
			fi
			echo -e "\t\tProcessing volume \"${volname}\"...";
			for chapter in ${vol}/chap-*; do
				chaptername=$(basename $chapter);
				if [[ "$chaptername" == "chap-*" ]]; then
					continue;
				fi
				chapter_dir=${backup_dir}/${volname}/${chaptername};
				mkdir -p ${chapter_dir};
				# process properties files
				for file in ${chapter}/*.properties; do
					fname=$(basename $file);
					fname=${fname%%.*};
					deleted=0;
					sha="";
					size=0;
					creation_time=0;
					repo_name="";
					content_type="";
					blob_name="";
					group_id="";
					artifact_id="";
					version="";
					qualifier="";
					packaging="";
					type="";
					is_metadata=0;
					# process attribute files
					while IFS= read -r line; do
						if [[ $line == deleted\=* ]]; then
							deleted=${line##deleted\=}
							if [[ $deleted == true ]]; then
								deleted=1;
							else
								deleted=0;
							fi
						fi
						if [[ $line == size* ]]; then
							size=${line##size\=}
						fi
						if [[ $line == sha* ]]; then
							sha=${line#sha1\=}
						fi
						if [[ $line == creationTime* ]]; then
							creation_time=${line##creationTime\=}
						fi
						if [[ $line == \@BlobStore\.content\-type* ]]; then
							content_type=${line##\@BlobStore\.content\-type\=}
						fi
						if [[ $line == \@BlobStore\.blob\-name* ]]; then
							blob_name=${line##\@BlobStore\.blob\-name\=};
							# some extra handling to figure out stuff
							last_segment=${blob_name##*/};
							if [[ ( $last_segment == "maven-metadata.xml" ) || ( $last_segment == "archetype-catalog.xml" ) ]]; then
								is_metadata=1;
							fi
							#now replace the last segment within the line so that we can extract the version
							verstr=${blob_name/\/${last_segment}/};
							version=${verstr##*/};
							artstr=${verstr/\/${version}/};
							if [[ ${version} == \- ]]; then
								aux=${last_segment##*-};
								version=${aux%\.*};
							fi
							# handle now artifactId
							artifact_id=${artstr##*/};
							# handle groupId
							groupstr=${artstr/\/${artifact_id}/};
							if [[ ${groupstr} != ${artifact_id} ]]; then
								group_id=${groupstr//\//\.};
							fi
							# handle qualifier
							aux=${last_segment/${artifact_id}-${version}/};
							type=${aux##*.};
							packaging=${aux#*.};
							if [[ ${aux:0:1} == "-" ]]; then
								aux=${aux##*-};
								aux=${aux%%.*};
								qualifier=$aux;
							fi
							if [[ ( $qualifier == javadoc ) && ( ${type} != sha1 ) && ( ${type} != md5 ) ]]; then
								packaging="javadoc"
							elif [[ ( $qualifier == sources ) && ( ${type} != sha1 ) && ( ${type} != md5 )  ]]; then
								packaging="java-source"
							fi
						fi
						if [[ $line == \@Bucket\.repo\-name* ]]; then
							repo_name=${line##\@Bucket\.repo\-name\=}
						fi
					done < "$file";
					# ignore deleted files
					if [[ ( $generate_sql == 1) && ( $deleted == 0 ) && ( $type != $artifact_id ) ]]; then
						# echo to file
						echo "INSERT INTO ARTIFACTS (sha1,size,deleted,creationTime,blobName,groupId,artifactId,version,type,qualifier,contentType,repoName,store,volume,chapter) VALUES ('${sha}',${size},${deleted},${creation_time},'${blob_name}','${group_id}','${artifact_id}','${version}','${type}','${qualifier}','${content_type}','${repo_name}','${dirname}','${volname}','${chaptername}');" >> ${export_file};
					fi
					if [[ ( $generate_csv == 1) && ( $deleted == 0 ) && ( $type != $artifact_id ) ]]; then
						# echo to file
						echo '"${sha}",${size},${deleted},${creation_time},"${blob_name}","${group_id}","${artifact_id}","${version}","${type}","${qualifier}","${content_type}","${repo_name}","${dirname}","${volname}","${chaptername}"' >> ${csv_file};
					fi
					if [[ ( $deploy_artifacts == 1) && ( $deleted == 0 ) && ( $is_metadata == 0 ) && ( $type != md5 ) && ( $type != sha1 ) && ( $type != $artifact_id ) ]]; then
						bin_file=${file/.properties/.bytes};
						skip_deploy=0;
						# Upload to devops
						artifact_type="maven";
						if [[ ${dirname:0:3} == npm ]]; then
							artifact_type="npm";
						fi
						vdir="${vrepo_dir}/${group_id}/${artifact_id}/${version}";
						vfile="${artifact_id}-${version}";
						echo -ne "\t\t\tDeploying ${artifact_type} blob \"${bin_file}\" to Artifacts (${group_id}/${artifact_id}-${version}";
						if [[ ${#qualifier} > 0 ]]; then
							echo -ne "-${qualifier}";
						fi
						if [[ $qualifier == "javadoc" ]]; then
							echo -ne ".jar ";
						elif [[ $qualifier == "java-source"  ]]; then
							echo -ne ".jar ";
						else
							echo -ne ".${packaging} ";
						fi
						has_javadoc=0;
						has_sources=0;
						fjavadoc=""
						fsources="";
						if [[ ( $type == jar ) && ( $qualifier != "java-source" ) && ( ${qualifier} != "javadoc" ) ]]; then
							if [[ -f "${vdir}/${vfile}-javadoc.jar" ]]; then
								fjavadoc="${vdir}/${vfile}-javadoc.jar";
								has_javadoc=1;
								echo -ne "[javadoc]";
							fi
							if [[ -f "${vdir}/${vfile}-sources.jar" ]]; then
								has_sources=1;
								fsources="${vdir}/${vfile}-sources.jar";
								echo -ne "[sources]";
							fi
						fi
						echo -ne ") ... ";
						# check if we should skip deployment
						if [[ ( $skip_deploy_karafassembly == 1 ) && ( ${is_assembly} == 1 ) ]]; then
							skip_deploy=1;
						elif [[ ( $skip_deploy_javadoc == 1 ) && ( ${qualifier} == "javadoc" ) ]]; then
							skip_deploy=1;
						elif [[ ( $skip_deploy_sources == 1 ) && ( ${qualifier} == "sources" ) ]]; then
							skip_deploy=1;
						fi

						if [[ ( $skip_deploy == 0 ) && ( ${dirname:0:5} == maven ) && ( ${dirname##*-} != proxy ) ]]; then
							# do not generate poms to avoid fails on actual pom upload
							cmd="mvn -nsu -B -ntp deploy:deploy-file -DgeneratePom=false -DgroupId=${group_id} -DartifactId=${artifact_id} -Dversion=${version} -Dpackaging=${packaging} -Dfile=${bin_file} -DrepositoryId=${repo_id} -Durl=${repo_url}";
							if [[ ${#qualifier} > 0 ]]; then
								cmd="${cmd} -Dclassifier=${qualifier}";
							fi
							# also we will only try to upload sources and javadoc for jar files
							if [[ ( $type == jar ) && ( $qualifier != "java-source" ) && ( ${qualifier} != "javadoc" ) ]]; then
								if [[ $has_sources == 1 ]]; then
									cmd="${cmd} -Dsources=${fsources}";
								fi
								if [[ $has_javadoc == 1 ]]; then
									cmd="${cmd} -Djavadoc=${fjavadoc}";
								fi
							fi
							cmd="${cmd} &> /dev/null";
							eval ${cmd};
							if [[ $? == 0 ]]; then
								print_ok;
							else
								print_fail;
							fi
						elif [[ ( $skip_deploy == 0 ) && ( ${dirname:0:3} == npm ) && ( ${dirname##*-} != proxy ) ]]; then
							tgz_file=$(basename ${file/.properties/.tgz});
							# we need to change the package json BEFORE publishing
							tar xf ${bin_file};
							# this will extract to /tmp (which is where we should be running this)
							# fix non lowercase package names
							pname=$(sed -rn 's/.*"name":.*"([^"]+)",/\1/p' "package/package.json" | tr '\r' '\n');
							sed -i 's|.*"name":.*"'${pname}'",|  "name": "'${pname,,}'",|g' "package/package.json";
							# fix non valid semver versions
							sed -ri 's/.*"version":.*"([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)",/  "version": "\1.\2.\3-\4",/g' "package/package.json";
							# now edit the package/package.json file
							sed -i "s|${nexus_npm_url}|${npm_url}|g" "package/package.json"
							# now create a new tar file
							tar czf ${tgz_file} package;
							# and publish
							npm publish ${tgz_file} &> /dev/null;
							if [[ $? == 0 ]]; then
								print_ok;
							else
								print_fail;
							fi
							# clean up package folder
							rm -rf package &> /dev/null;
							# clean up tgz file
							rm -f ${tgz_file};
						elif [[ $skip_deploy == 1 ]]; then
							print_skip;
						else
							print_ignr;
						fi
					fi
				done
			done
		done
	done
}

# generate a virtual repo
generate_vrepo;
# then process blobs
process_blobs;

echo
echo "Script finished.";