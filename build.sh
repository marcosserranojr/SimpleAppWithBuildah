#!/bin/bash

version=$1
REGISTRY_USERNAME=$2
REGISTRY_TOKEN=$3
destination="docker://registry.hub.docker.com/"$REGISTRY_USERNAME"/simple-app:"$version

echo "---CREATE THE BUILD CONTAINER FROM SDK IMAGE----"
echo "------------------------------------------------"
echo "Assign the base image to a variable that will be used to build the app"
buildcontainer=$(buildah from mcr.microsoft.com/dotnet/sdk:5.0)
echo "Now set the working dirctory via the config command and specify the container to create the working directory in"
buildah config --workingdir /src $buildcontainer
echo "Copy over the .csproj file over to the Container's working dir root"
buildah copy $buildcontainer ./simple-app.csproj ./
echo "Execute the dotnet restore prior to publish"
buildah run $buildcontainer dotnet restore ./simple-app.csproj
echo "---------------------------------------------------------"
echo "Copy from root of source to root of destination (workingDir)"
buildah copy $buildcontainer ./ ./
echo "We are still in working directory"
echo "Now we run publish with an output folder of app/publish"
buildah run $buildcontainer dotnet publish ./simple-app.csproj -c Release -o /app/publish
echo "Need to copy the contenets of the build container over to the final container"
echo" Lets map the container to the host file system"
buildcontainermount=$(buildah mount $buildcontainer)
echo "MOUNT PATH"
echo $buildcontainermount
echo "------------------------------------------------------"
echo "------------Build stage complete----------------------"
echo ""
echo "-------------------------------------------------------"
echo "CREATE FINAL IMAGE USING RUNTIME IMAGE INSTEAD OF SDK"
echo "--------------------------------------------------------"
ECHO ""
echo "First assign the runtime image to a variablein order to build final image"
finalcontainer=$(buildah from mcr.microsoft.com/dotnet/aspnet:5.0)
echo "Now set the working dirctory via the config command in the container"
buildah config --workingdir /app $finalcontainer
echo "Expose the appropriate ports for final container"
buildah config --port 80 $finalcontainer
buildah config --port 443 $finalcontainer
echo "Now you need to mount final container in order to copy everything form build container to final container"
finalcontainermount=$(buildah mount $finalcontainer)
echo "MOUNT PATH"
echo $finalcontainermount
echo "----------------------------------------------"
echo "Now copy the contents of /app/publish over to /app within the containers on the local file system "
cp -r $buildcontainermount/app/publish $finalcontainermount/app
echo "Now specify the entry point via config command"
buildah config --entrypoint 'dotnet simple-app.dll' $finalcontainer
echo "-------All of the Docker File steps have been Reproduced via Buildah-----------"
echo ""
echo"-----------------------------------------------------------"
echo "CREATE AN IMAGE FROM THE finalcontainer"
echo "----------------------------------------------------------"
echo "Using BUILDAH COMMIT to commit an image"
echo "To tell buildah to use docker image manifest vs OCI use the --format flag"
buildah commit --format=docker $finalcontainer simple-app:$version
echo ""
echo "LISTING IMAGES BUILDAH HAS"
echo "-------------------------------------------------------------------------"
buildah images
echo "--------------------------------------------------------------------------"
echo ""
echo "clean up both mounts and intermediate images created"
buildah unmount --all
buildah rm --all
echo ""
echo "-----------------------------------------------------------------------------"
echo " PUSH TO REGISTRY"
echo "-----------------------------------------------------------------------------"
echo " We need to provide 2 parameters - what we want to push and where"
echo ""
buildah push --creds $REGISTRY_USERNAME:$REGISTRY_TOKEN localhost/simple-app:$version $destination 




