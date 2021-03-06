# 以太坊创建Token
***本文档基于Rinkeby测试网络***

## 以太坊账户

### 通过MetaMask创建账户

登录metamask官网或者谷歌商店，通过插件的方式安装在浏览器上，本文档中使用的Chrome浏览器

![](https://github.com/lynAzrael/L/blob/master/share/img/metamask_chrome.png)

使用metamask创建账户

![](https://github.com/lynAzrael/L/blob/master/share/img/create_account_metamask.png)

### 私钥导出

进入到处私钥界面

![step 1](https://github.com/lynAzrael/L/blob/master/share/img/prepare_dump_key.png)

输入创建用户时设置的密码

![](https://github.com/lynAzrael/L/blob/master/share/img/passwd_dump_key.png)

记录好自己的私钥信息

![](https://github.com/lynAzrael/L/blob/master/share/img/dump_key_info.png)

***创建账户地址之后，将私钥保管好。私钥一旦丢失，账户中的财产就无法找回。***

## 测试币的获取
[https://www.rinkeby.io/#faucet](https://www.rinkeby.io/#faucet)

使用收币地址生成public gist链接

![](https://github.com/lynAzrael/L/blob/master/share/img/create_public_gist.png)

使用生成的链接获取测试Ether

![](https://github.com/lynAzrael/L/blob/master/share/img/rinkeby_authenticated_faucet.png)

视频参考：[https://www.youtube.com/watch?v=wKFz5c3TU4s](https://www.youtube.com/watch?v=wKFz5c3TU4s)


## Token合约

### 合约源码
```sol
pragma solidity ^0.4.13;

contract Token {

    /// @return total amount of tokens
    function totalSupply() constant returns (uint256 supply) {}

    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address _owner) constant returns (uint256 balance) {}

    /// @notice send `_value` token to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _value) returns (bool success) {}

    /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {}

    /// @notice `msg.sender` approves `_addr` to spend `_value` tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _value The amount of wei to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address _spender, uint256 _value) returns (bool success) {}

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens allowed to spent
    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {}

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

}

contract StandardToken is Token {

    function transfer(address _to, uint256 _value) returns (bool success) {
        //Default assumes totalSupply can't be over max (2^256 - 1).
        //If your token leaves out totalSupply and can issue more tokens as time goes on, you need to check if it doesn't wrap.
        //Replace the if with this one instead.
        //if (balances[msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        } else { return false; }
    }

    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        //same as above. Replace this line with the following if you want to protect against wrapping uints.
        //if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            Transfer(_from, _to, _value);
            return true;
        } else { return false; }
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    uint256 public totalSupply;
}

contract MsnCoin is StandardToken { 

    /* Public variables of the token */

    /*
    NOTE:
    The following variables are OPTIONAL vanities. One does not have to include them.
    They allow one to customise the token contract & in no way influences the core functionality.
    Some wallets/interfaces might not even bother to look at this information.
    */
    string public name;                   // Token Name
    uint8 public decimals;                // How many decimals to show. To be standard complicant keep it 18
    string public symbol;                 // An identifier: eg SBX, XPR etc..
    string public version = '1.0'; 
    uint256 public unitsOneEthCanBuy;     // 1 eth 可以购买的token数量?
    uint256 public totalEthInWei;         // 募集到的所有ETH  
    address public fundsWallet;           // 保存资金的地址

    // This is a constructor function 
    // which means the following function name has to match the contract name declared above
    function MsnCoin() {
        balances[msg.sender] = 1000000000000000000000;               // 合约创建者获得所有的token吗，这里是1000
        totalSupply = 1000000000000000000000;                        // 1000 总量
        name = "MsnCoin";                                         // token名称
        decimals = 18;                                               // 小数点位
        symbol = "MSN";                                             // 标识
        unitsOneEthCanBuy = 10;                                      // 一个ETH 可以购买的token数量
        fundsWallet = msg.sender;                                    // 合约创建者默认是资金账户
    }

    // 其他地址向合约发送ETH，默认会执行这个方法
    function() payable{
        // 更新募集到的ETH总量
        totalEthInWei = totalEthInWei + msg.value;
        // 计算购买token的数量
        uint256 amount = msg.value * unitsOneEthCanBuy;
        // 检测资金账户的token余额大于或等于购买的数量
        require(balances[fundsWallet] >= amount);

        // 资金账户token减少购买的数量
        balances[fundsWallet] = balances[fundsWallet] - amount;
        // 发送ETH的账户增加购买token的数量
        balances[msg.sender] = balances[msg.sender] + amount;

        // 广播购买事件
        Transfer(fundsWallet, msg.sender, amount); 

        // 把ETH转给资金账户
        fundsWallet.transfer(msg.value);                               
    }

    /* Approves and then calls the receiving contract */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);

        //call the receiveApproval function on the contract you want to be notified. This crafts the function signature manually so one doesn't have to include a contract in here just for this.
        //receiveApproval(address _from, uint256 _value, address _tokenContract, bytes _extraData)
        //it is assumed that when does this that the call *should* succeed, otherwise one would use vanilla approve instead.
        if(!_spender.call(bytes4(bytes32(sha3("receiveApproval(address,uint256,address,bytes)"))), msg.sender, _value, this, _extraData)) { throw; }
        return true;
    }
}
```

### 合约部署
使用[remix](https://remix.ethereum.org/)进行合约的编译以及部署

选择solidity编译环境并创建一个新的sol文件

![new sol file](https://github.com/lynAzrael/L/blob/master/share/img/solidity_env_and_new_file.png)

编译版本选择4.13，然后点击Compile按钮

![compile contract](https://github.com/lynAzrael/L/blob/master/share/img/contract_compile.png)

之后进入的部署界面进行部署

![deploy contract](https://github.com/lynAzrael/L/blob/master/share/img/enter_deploy_after_compile.png)

设置总发行量，精度，token名称以及token的标记

|字段|取值|
|----|----|
|totalSupply|21000000|
|decimalUnits|3|
|tokenName|ASD|
|tokenSymbol|asd|

合约的部署

![](https://github.com/lynAzrael/L/blob/master/share/img/deploy_contract.png)

部署合约的交易

![](https://github.com/lynAzrael/L/blob/master/share/img/contract_transfer_tx.png)

通过区块浏览器查看交易的具体信息

浏览器地址: [https://ropsten.etherscan.io](https://ropsten.etherscan.io)

> 本次合约部署位于Rinkeby测试网，因此使用Rinkeby的区块链浏览器。主网的区块链浏览器地址 [https://cn.etherscan.com](https://cn.etherscan.com)

![contract_tx_detail](https://github.com/lynAzrael/L/blob/master/share/img/contract_tx_detail.png)


成功部署之后，可以在remix上查看合约的地址以及支持的操作

![deployed_contract](https://github.com/lynAzrael/L/blob/master/share/img/deployed_contract_info.png)

将合约地址添加到MetaMask的钱包中，可以看到创建的token

![](https://github.com/lynAzrael/L/blob/master/share/img/add_token_by_contract_address.png)

![](https://github.com/lynAzrael/L/blob/master/share/img/token_info_in_metamask.png)




