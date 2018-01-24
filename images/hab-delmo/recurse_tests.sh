#!/bin/bash

if [ ! -z ${MACHINE_NAME} ] && [ ! -z ${MACHINE_EXPORT_AWS_ACCESS_KEY_ID} ] \
    && [ ! -z ${MACHINE_EXPORT_AWS_SECRET_ACCESS_KEY} ] &&  [ ! -z ${MACHINE_EXPORT_AWS_REGION} ] \
    && [ ! -z ${MACHINE_EXPORT_AWS_BUCKET} ]; then
    echo "Downloading pre existing docker-machine configuration..."
    (
      export AWS_ACCESS_KEY_ID=${MACHINE_EXPORT_AWS_ACCESS_KEY_ID}
      export AWS_SECRET_ACCESS_KEY=${MACHINE_EXPORT_AWS_SECRET_ACCESS_KEY}
      export AWS_DEFAULT_REGION=${MACHINE_EXPORT_AWS_REGION}
      aws --region ${MACHINE_EXPORT_AWS_REGION} s3 cp s3://${MACHINE_EXPORT_AWS_BUCKET}/${MACHINE_NAME}.zip ./
    ) || exit 1

    echo "Importing configuration..."
    machine-import ${MACHINE_NAME}.zip
    # The permission isn't set properly on import
    chmod 0600 /root/.docker/machine/machines/${MACHINE_NAME}/id_rsa

    echo "Machine ${MACHINE_NAME} imported!"

    echo "Deleting all existing containers..."
    eval $(docker-machine env --shell sh ${MACHINE_NAME})
    docker ps -a | grep -v CONTAINER | awk '{print $1}' | xargs docker rm -f
fi

cd $GROUP_CONTEXT

build_idents=$(cat ./* | jq '[.group[]| .ident]'| tr -d '[]()""' | tr ',' '\n')

for ident in ${build_idents[@]}; do
  pkg_path="/hab/pkgs/$ident"

  hab pkg install $ident

  if [ -f "$pkg_path/tests/delmo.yml" ]; then
      delmo --only-build-task -f "$pkg_path/tests/delmo.yml" -m ${MACHINE_NAME}
  else
      echo "No tests in pkg: $ident"
  fi
done

