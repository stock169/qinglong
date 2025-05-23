#!/usr/bin/env bash

# 前置依赖 nodejs、npm
set -e
set -x

if [[ ! $QL_DIR ]]; then
  npm_dir=$(npm root -g)
  pnpm_dir=$(pnpm root -g)
  if [[ -d "$npm_dir/@whyour/qinglong" ]]; then
    QL_DIR="$npm_dir/@whyour/qinglong"
  elif [[ -d "$pnpm_dir/@whyour/qinglong" ]]; then
    QL_DIR="$pnpm_dir/@whyour/qinglong"
  else
    echo -e "未找到 qinglong 模块，请先执行 npm i -g @whyour/qinglong 安装"
  fi

  if [[ $QL_DIR ]]; then
    echo -e "请先手动设置 export QL_DIR=$QL_DIR，环境变量，并手动添加到系统环境变量，然后再次执行命令 qinglong 启动服务"
  fi

  exit 1
fi

if [[ ! $QL_DATA_DIR ]]; then
  echo -e "请先手动设置数据存储目录 export QL_DATA_DIR 环境变量，目录必须以斜杠开头的绝对路径，并手动添加到系统环境变量"
  exit 1
fi

# 安装依赖
os_name=$(source /etc/os-release && echo "$ID")

if [[ $os_name == 'alpine' ]]; then
  apk update
  apk add -f bash \
    coreutils \
    git \
    curl \
    wget \
    tzdata \
    perl \
    openssl \
    jq \
    nginx \
    openssh \
    procps \
    netcat-openbsd
elif [[ $os_name == 'debian' ]] || [[ $os_name == 'ubuntu' ]]; then
  apt-get update
  apt-get install -y git curl wget tzdata perl openssl jq nginx procps netcat-openbsd openssh-client
else
  echo -e "暂不支持此系统部署 $os_name"
  exit 1
fi

npm install -g pnpm@8.3.1 pm2 ts-node

cd ${QL_DIR}
cp -f .env.example .env
chmod 777 ${QL_DIR}/shell/*.sh

. ${QL_DIR}/shell/env.sh
. ${QL_DIR}/shell/share.sh

echo -e "======================1. 检测配置文件========================\n"
make_dir /etc/nginx/conf.d
make_dir /run/nginx
init_nginx
fix_config

pm2 l &>/dev/null

echo -e "======================2. 安装依赖========================\n"
patch_version

echo -e "======================3. 启动nginx========================\n"
nginx -s reload 2>/dev/null || nginx -c /etc/nginx/nginx.conf
echo -e "nginx启动成功...\n"

reload_update
reload_pm2

if [[ $AutoStartBot == true ]]; then
  echo -e "======================5. 启动bot========================\n"
  nohup ql bot >$dir_log/bot.log 2>&1 &
  echo -e "bot后台启动中...\n"
fi

if [[ $EnableExtraShell == true ]]; then
  echo -e "====================6. 执行自定义脚本========================\n"
  nohup ql extra >$dir_log/extra.log 2>&1 &
  echo -e "自定义脚本后台执行中...\n"
fi

echo -e "############################################################\n"
echo -e "启动完成..."
echo -e "############################################################\n"
