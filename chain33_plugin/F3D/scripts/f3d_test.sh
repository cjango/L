#!/bin/sh

# . "../util/common.sh"

start="225"
count="230"
managerAddr="14KEKbYtKKQm4wMthSK9J4La4nAiidGozt"
userinfoTempfile=".userinfo_temp"
addressInfo=".addr_info"
addrbalanceInfo=".addr_balance_info"
config_file="exec_config"
rpc_addr="http://localhost:8801"

function CheckAddressInfoFile()
{
    if [ -f ${addressInfo} ]; then
        rm ${addressInfo}
        touch ${addressInfo}
    fi

    if [ -f ${addrbalanceInfo} ]; then
        rm ${addrbalanceInfo}
        touch ${addrbalanceInfo}
    fi
}

function CreateUser() 
{
    username="f3d_user"$i
    GetMethodInfo "CreateUser"
    addUserMethod="${method}"
    GetParamsInfo "CreateUser"
    RefreshParamString "${param}" "label" "${username}"
    addUserParamsInfo="[${param}]"
    
    Curl "${addUserMethod}" "${addUserParamsInfo}"
    if [ $? -ne 0 ]; then
        errInfo=`echo ${res} | awk -F '"' '{print $8}'`
        echo "${username} => ${errInfo}"
        continue
    else
        echo "${res}" > ${userinfoTempfile}
        cat ${userinfoTempfile}
        address=`cat ${userinfoTempfile} | grep "addr" | awk -F '"' '{print $10}'`
        echo "${username}:${address}" >> ${addressInfo}
        TransferToUser ${address} "100000"
        TransferToExecFromAccount "90000" "f3d"
    fi
}

function Transfer()
{
    for ((i=$start; i < ${count}; i++))
    do 
        username="f3d_user"$i
        GetAddressByLabel $username
        if [ "X${address}" == "X" ]; then
            continue
        fi
        TransferToUser ${address} "100000"
        TransferToExecFromAccount "90000" "f3d"
    done
}

function Start()
{
    GetMethodInfo "Start"
    startMethod="${method}"
    GetParamsInfo "Start"
    RefreshParamInt64 "${param}" "round" 1
    startParamsInfo="[${param}]"

    Curl "${startMethod}" "${startParamsInfo}"
    if [ $? -ne 0 ]; then
        echo "Start new round failed, errInfo: ${res}"
        exit 1
    else
        unsignedTx=`echo ${res} | awk -F '"' '{print $6}'`
        Sign ${unsignedTx} ${managerAddr}
        sleep 0.5
    fi
}

function Stop()
{
    GetMethodInfo "Stop"
    stopMethod="${method}"
    GetParamsInfo "Stop"
    RefreshParamInt64 "${param}" "round" 1
    stopParamsInfo="[${param}]"

    Curl "${stopMethod}" "${stopParamsInfo}"
    if [ $? -ne 0 ]; then
        echo "Stop new round failed, errInfo: ${res}"
        exit 1
    else
        unsignedTx=`echo ${res} | awk -F '"' '{print $6}'`
        Sign ${unsignedTx} ${managerAddr}
        sleep 0.5
    fi
}

function Buy()
{
    GetMethodInfo "Buy"
    buyKeysmethod="${method}"
    GetParamsInfo "Buy"
    RefreshParamInt64 "${param}" "num" "1"
    RefreshParamString "${param}" "txhash" ""
    buyKeysParamsInfo="[${param}]"

    for line in `cat ${addressInfo} | grep -v "^$"`
    do 
        Curl "${buyKeysmethod}" "${buyKeysParamsInfo}"
        if [ $? -ne 0 ]; then
            continue
        else
            unsignedTx=`echo ${res} | awk -F '"' '{print $6}'`
            address=`echo ${line} | awk -F ':' '{print $2}'`
            Sign ${unsignedTx} ${address}
            sleep 0.5
        fi
    done
}

function GetMethodInfo()
{
    section=$1
    GetKeyInfo "${section}" "method"
    method="${value}"
}

function GetParamsInfo()
{
    section=$1
    GetKeyInfo "${section}" "param"
    param="${value}"
}

function GetAddressByLabel()
{
    label=$1
    address=`cat ${addressInfo} | grep "${label}:" | awk -F ":" '{print$2}'`
}

function CheckBalance() 
{
    checkstart=$1
    for ((i=$checkstart; i < ${count}; i++))
    do 
        username="f3d_user"$i
        GetAddressByLabel $username
        ./chain33-cli account balance -a ${address} > ${addrbalanceInfo}
        balanceinfotime=`cat ${addrbalanceInfo} | grep balance | wc -l`
        # 账户中余额，且合约地址中也有余额
        if [ ${balanceinfotime} == 2 ]; then
            rm ${addrbalanceInfo}
            continue
        # 账户中有余额，但是合约地址中没有
        elif [ ${balanceinfotime} == 1 ]; then
            TransferToExecFromAccount "1000" "f3d"
            # sleep 0.5
        # 账户中没有钱，同样合约地址中也没有
        elif [ ${balanceinfotime} == 0 ]; then
            TransferToUser ${address} "2000"
            # sleep 0.5
            TransferToExecFromAccount "1000" "f3d"
            # sleep 0.5
        else
            echo "wrong balance info"
        fi

        balance=`cat ${addrbalanceInfo} | grep balance | awk -F '"' '{print $4}'`
        rm ${addrbalanceInfo}
        # sleep 0.5
    done
}

function TransferToUser()
{
    rcvrAddr=$1
    amount=$2
    res=`./chain33-cli send bty transfer -a ${amount} -k ${managerAddr} -t ${rcvrAddr}`
    while [ "$res" == "ErrTxExpire" ]; 
    do
        sleep 10
        res=`./chain33-cli send bty transfer -a ${amount} -k ${managerAddr} -t ${rcvrAddr}`
    done
}
    

function TransferToExecFromAccount()
{
    amount=$1
    executor_name=$2
    unsignedTx=`./chain33-cli bty send_exec -a ${amount} -e ${executor_name}`
    Sign ${unsignedTx} ${address}
}

function Exec() 
{
    cmd=$*
    res=`$cmd`
    Sign ${res} ${addr}
}

function Sign()
{
    unsignedTx=$1
    sendaddr=$2
    GetMethodInfo "Sign"
    signMethod="${method}"
    GetParamsInfo "Sign"
    RefreshParamString "${param}" "addr" "${sendaddr}"
    RefreshParamString "${param}" "txHex" "${unsignedTx}"
    signParamsInfo="[${param}]"

    Curl "${signMethod}" "${signParamsInfo}"
    if [ $? -eq 0 ]; then 
        signedTx=`echo ${res} | awk -F '"' '{print $6}'`
        Send ${signedTx}
    else
        echo "${res}"
    fi
   
}

function Send() 
{
    signedtx=$1
    GetMethodInfo "Send"
    sendMethod="${method}"
    GetParamsInfo "Send" "param"
    RefreshParamString "${param}" "data" "${signedtx}"
    sendParamsInfo="[${param}]"

    Curl "${sendMethod}" "${sendParamsInfo}"
    if [ $? -ne 0 ]; then
        errorInfo=`echo ${res} | awk -F '"' '{print $8}'`
        echo "${errorInfo}"
    fi
}

function SaveSeed()
{
    GetMethodInfo "SaveSeed"
    saveMethod="${method}"
    GetParamsInfo "SaveSeed" "param"
    saveParamsInfo="[${param}]"

    Curl "${saveMethod}" "${saveParamsInfo}"
    if [ $? -ne 0 ]; then
        errorInfo=`echo ${res} | awk -F '"' '{print $8}'`
        echo "${errorInfo}"
    fi
}

function Unlock()
{
    GetMethodInfo "Unlock"
    unlockMethod="${method}"
    GetParamsInfo "Unlock" "param"
    unlockParamsInfo="[${param}]"

    Curl "${unlockMethod}" "${unlockParamsInfo}"
    if [ $? -ne 0 ]; then
        errorInfo=`echo ${res} | awk -F '"' '{print $8}'`
        echo "${errorInfo}"
    fi
}

function ImportKey()
{
    GetMethodInfo "ImportKey"
    importMethod="${method}"
    GetParamsInfo "ImportKey" "param"
    importParamsInfo="[${param}]"

    Curl "${importMethod}" "${importParamsInfo}"
    if [ $? -ne 0 ]; then
        errorInfo=`echo ${res} | awk -F '"' '{print $8}'`
        echo "${errorInfo}"
    fi
}

function GetKeyInfo()
{
    section=$1
    key=$2
    value=`sed -n "/^\[${section}/,/^\[/p" ${config_file} | grep ${key} | awk -F '=' '{print $2}' | tr -d '\r'`
}

function Curl()
{
    method=$1
    params=$2
    res=`curl --data-binary '{"jsonrpc":"2.0", "method": '"${method}"', "params": '"${params}"' , "id": 0}' -H 'content-type:text/plain;' ${rpc_addr} -s`
    if [[ "${res}" =~ "Err" ]]; then 
        return 1
    else
        return 0
    fi
}

function RefreshParamString() 
{
    oldParam=$1
    refreshKey=$2
    refreshVal=$3

    # 使用jq后续curl指令执行有问题
    # param=`echo ${oldParam} | jq 'to_entries | map(if .key == "'${refreshKey}'" then . + {"value": "'${refreshVal}'"} else . end) | from_entries'`
    param=`echo "${oldParam}" | awk ' { for (i=1;i<=NF;i++) {if (match($i, "'${refreshKey}'")) {gsub(/inputParam/, "'${refreshVal}'", $(i+1)); print}} }'`
}

function RefreshParamInt64()
{
    oldParam=$1
    refreshKey=$2
    refreshVal=$3

    param=`echo "${oldParam}" | awk ' { for (i=1;i<=NF;i++) {if (match($i, "'${refreshKey}'")) {gsub(/\"inputParam\"/, '${refreshVal}', $(i+1)); print}} }'`
}

function OperationCheck()
{
    opName=$1
    sectionInfo=`cat exec_config | sed -n "/^\[${opName}\].*$/,/^\[/p"`
    methodInfo=`echo "${sectionInfo}"  | grep "method" | tr -d '\r\n'`
    paramInfo=`echo "${sectionInfo}"  | grep "param" | tr -d '\r\n'`

    if [[ "${methodInfo}" != "" && "${paramInfo}" != "" ]]; then
        return 0
    else
        return 1
    fi
}

function GetPreset()
{
    GetKeyInfo "Run" "preset"
    presetOps="${value}"
}

function GetImplement()
{
    GetKeyInfo "Run" "implement"
    implementOps="${value}"
}

function GetCheckRule()
{
    return 0
}

function PresetStatusCheck()
{
    # TODO: preset状态检查
    return 0
}

function RunPreset()
{
    GetPreset
    CheckAddressInfoFile

    for op in `echo "${presetOps}" | awk 'BEGIN {FS="[,\"\\\[\\\]]"} {for (i=1;i<=NF;i++) {if ($i != "") print $i} }'`
    do 
        RunOp "${op}"
        sleep 1
    done
}

function RunImplement()
{
    # 判断preset是否执行完毕
    PresetStatusCheck
    if [ $? -ne 0 ]; then
        return 1
    fi

    GetImplement
    for op in `echo "${implementOps}" | awk 'BEGIN {FS="[,\"\\\[\\\]]"} {for (i=1;i<=NF;i++) {if ($i != "") print $i} }'`
    do 
        OperationCheck ${op}
        if [ $? -eq 0 ]; then
            RunOp "${op}"
        fi
    done
}

function PreCheck()
{
    GetKeyInfo "${opName}" "${check}"
    if [ "${value}" == "true" ]; then
        return 0
    else
        return 1
    fi
}

function RunCheck()
{
    
}

function RunOp()
{
    opName=$1

    # 判断是否需要状态检查
    PreCheck
    if [ $? -eq 0 ]; then
        RunCheck
    fi 


    GetKeyInfo "${opName}" "times"
    times=${value}

    # 根据[op]中配置的次数进行循环操作, times没有配置默认执行一次
    if [ "${times}" == "" ]; then
        times=1
    fi

    for ((i=0; i < ${times}; i++))
    do
        ${opName}
    done
}

function Run()
{
    # 获取implement循环次数
    GetKeyInfo "Run" "runtimes"
    runtimes=${value}
    # 执行预置条件
    RunPreset
    
    # 根据[run]中配置的次数，进行循环操作
    if [ ${runtimes} -eq 0 ]; then
        while true
        do
            RunImplement
        done
    else
        for ((i=0; i < ${runtimes}; i++))
        do
            RunImplement
        done
    fi
    
}



# function main()
# {
#     GetKeyInfo "Op" "ops"
#     ops=`echo ${value} | awk 'BEGIN{FS="[,\"]"} {for (i=1;i<NF;i++) {if ($i != "") print $i}}'`
    
#     while true
#     do
#         echo "Please input your operation. Support("${ops}"), quit to exit."
#         read op
#         if [ "${op}" == "quit" ]; then
#             break
#         elif [[ "${ops}" =~ "${op}" ]]; then
#             #statements
#             echo "Begin to ${op}..."
#             GetKeyInfo "${op}" "needRange"
#             if [ "${value}" == '"true"' ]; then
#                 echo "please input range, like 10,20."
#                 read range
#                 min=`echo "${range}" | awk -F ',' '{print $1}'`
#                 max=`echo "${range}" | awk -F ',' '{print $2}'`
#                 ${op} ${min} ${max}
#             else
#                 ${op}
#             fi
#         else
#             echo "Operation is not support."
#         fi
#     done

#     echo "Closing..."
# }

# op=$1
# if [ "X${op}" == "Xcreate" ]; then
#     CheckAddressInfoFile
#     CreateUser
# elif [ "X${op}" == "Xtransfer" ]; then
#     Transfer
# elif [ "X${op}" == "Xbuy" ]; then
#     buystart=$2
#     BuyKeys $buystart
# elif [[ "X${op}" == "Xcheck_balance" ]]; then
#     #statements
#     checkstart=$2
#     CheckBalance $checkstart
# else
#     echo "Invalid operation."
# fi

# main

Run