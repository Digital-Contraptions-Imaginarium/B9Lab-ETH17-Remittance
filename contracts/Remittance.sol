pragma solidity ^0.4.15;

contract Remittance {

    address public carol;
    uint public amount;
    // the exchange rate is expressed as an integer, e.g. 3 means 1 ether = 3 units of currency
    uint public ether2CurrencyRate;
    // commission percentage is expressed as an integer, e.g. 2 for 2%
    uint public commissionPercentage;
    bytes32 public bobsKeccak256;
    bytes32 public carolsKeccak256;
    bool public waitingForWithdrawal;

    event LogDeposit(address userAddress, uint depositAmount);
    event LogCommission(address userAddress, uint commissionAmount);
    event LogWithdrawal(address userAddress, uint localCurrencyAmount);

    // NOTE: the contract creator is the exchange shop (Carol), as she needs to set the
    // currency rate and commission % before Alice decides to use their services.
    function Remittance(uint _ether2CurrencyRate, uint _commissionPercentage)
        public
    {
        carol = msg.sender;
        ether2CurrencyRate = _ether2CurrencyRate;
        commissionPercentage = _commissionPercentage;
    }

    // this is the function Alice uses to deposit into the contract and specify Bob and Carol's
    // passwords; the password are converted to their hash by JavaScript on the browser, before
    // calling the deposit function
    function deposit(bytes32 _bobsKeccak256, bytes32 _carolsKeccak256)
        public
        payable
        returns(bool)
    {
        require(!waitingForWithdrawal);
        require(msg.value > 0);
        // if Carol is trying to send money to some Bob using her own service, it must be a mistake
        require(msg.sender != carol);

        amount = msg.value;
        bobsKeccak256 = _bobsKeccak256;
        carolsKeccak256 = _carolsKeccak256;
        waitingForWithdrawal = true;
        LogDeposit(msg.sender, msg.value);
        return(true);
    }

    // Withdraw needs to be called by Carol, with Bob being present for the hash of his password.
    // It credits her with the commission, and returns in the LogDeposit event the amount to
    // credit Bob in Wei and in local currency.
    function withdraw(bytes32 _bobsKeccak256, bytes32 _carolsKeccak256)
        public
        returns(uint commissionAmount, uint toPayInLocalCurrency)
    {
        require(msg.sender == carol);
        require(waitingForWithdrawal);
        require((bobsKeccak256 == _bobsKeccak256) && (carolsKeccak256 == _carolsKeccak256));

        commissionAmount = amount * commissionPercentage / uint(100);
        toPayInLocalCurrency = (amount - commissionAmount) / uint(1000000000000000000) * ether2CurrencyRate;
        msg.sender.transfer(commissionAmount);
        LogCommission(msg.sender, commissionAmount);
        LogWithdrawal(msg.sender, toPayInLocalCurrency);
        return(commissionAmount, toPayInLocalCurrency);
    }

}
