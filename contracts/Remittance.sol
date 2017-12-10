pragma solidity ^0.4.15;

// This is a first basic implementation of the problem. Situations that still need being managed
// are:
// - Bob is currently paying the commission: is that fair? Shouldn't it be Alice?
// - Bob and Carol never meet and Alice's money is frozen in the contract: this can be solved
//   by allowing Alice to get the money back after a certain time (blocks)
// - What if withdraw fail? It is not clear if the current code will revert also the withdrawn
//   variable being set to true, if the transfer fails.

contract Remittance {

    address public alice;
    address public carol;
    // the exchange rate is expressed as an integer, e.g. 3 means 1 ether = 3 units of currency
    uint public ether2CurrencyRate;
    // commission percentage is expressed as an integer, e.g. 2 for 2%
    uint public commissionPercentage;
    bytes32 public bobsKeccak256;
    bytes32 public carolsKeccak256;
    bool public deposited;
    bool public waitingForTransfer;
    bool public successfulTransfer;
    bool public refunded;

    event LogDeposit(address userAddress, uint depositAmount);
    event LogCommission(address userAddress, uint commissionAmount);
    event LogTransfer(bool success, address userAddress, uint localCurrencyAmount);
    event LogRefund(address userAddress, uint refundAmount);

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
        require(!deposited);
        require(msg.value > 0);

        deposited = true;
        waitingForTransfer = true;
        alice = msg.sender;
        bobsKeccak256 = _bobsKeccak256;
        carolsKeccak256 = _carolsKeccak256;
        LogDeposit(alice, this.balance);
        return(true);
    }

    // This function credits Carol with the whole value of the contract, and returns in
    // LogTransfer the information required to pay Bob in local currency, minus the commission.
    // It needs to be called Carol, with Bob being present, so that they can input both
    // their passwords as they were assigned to them by Alice.
    // It has to be called by Carol as it is fair that she pays for the gas, as she gets a
    // commission compensating her.
    // Note: because the passwords are visible in the transaction payload, they should not be used
    //       more than once. Hence, if transferring the money to Carol fails, the whole operation
    //       needs being cancelled, and Alice enabled to get a refund.
    function transfer(string _bobsPassword, string _carolsPassword)
        public
        returns(bool success, uint commissionAmount, uint toPayInLocalCurrency)
    {
        // only Carol can trigger the transfer...
        require(msg.sender == carol);
        // ... if the money was deposited, and transfer not attempted yet
        require(deposited && waitingForTransfer);
        // .. and if the passwords are correct
        require((bobsKeccak256 == keccak256(_bobsPassword)) && (carolsKeccak256 == keccak256(_carolsPassword)));

        waitingForTransfer = false;
        commissionAmount = this.balance * commissionPercentage / uint(100);
        toPayInLocalCurrency = (this.balance - commissionAmount) / uint(1000000000000000000) * ether2CurrencyRate;
        successfulTransfer = carol.send(this.balance);
        LogTransfer(successfulTransfer, msg.sender, toPayInLocalCurrency);
        if (successfulTransfer) LogCommission(msg.sender, commissionAmount);
        return(successfulTransfer, commissionAmount, toPayInLocalCurrency);
    }

    // If Bob and Carol use their passwords correctly but the transfer of the funds to Carol
    // fails, they should not use the passwords again and the only action possible is for Alice
    // to be refunded.
    function refund()
        public
        returns(bool)
    {
        // only Alice can ask for a refund of course
        require(msg.sender == alice);
        // ... and there must be money to refund
        require(this.balance > 0);
        // ... and a previous transfer to Carol must have been attempted and failed
        require(!waitingForTransfer && !successfulTransfer);
        // ... and refund was not attempted before
        require(!refunded);

        refunded = true;
        msg.sender.transfer(this.balance);
        LogRefund(alice, this.balance);
        return(true);
    }

}
