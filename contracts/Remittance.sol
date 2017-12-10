pragma solidity ^0.4.15;

contract Remittance {

    // that's the exchange shop's address
    address public owner;
    // the exchange rate is expressed as an integer, e.g. 3 means 1 Wei = 3 units of currency
    uint public wei2CurrencyRate;
    // commission percentage is expressed as an integer, e.g. 2 for 2%
    uint public commissionPercentage;
    // the default duration of each remittance instruction is expressed in no. of blocks
    // following the deposit, after which the sender is entitled to a refund
    uint public defaultDuration;

    struct RemittanceInstruction {
        address sender;
        uint expirationBlock; // the latest possible block no. to transfer
        uint depositedAmount; // Wei
        uint commissionAmount; // Wei
        uint localCurrencyAmount; // local currency
        bytes32 beneficiaryPasswordHash;
        bytes32 exchangePasswordHash;
    }
    mapping (address => RemittanceInstruction) public remittanceInstructions;

    event LogDeposit(address sender, uint depositedAmount);
    event LogTransfer(address sender, uint localCurrencyAmount, uint commissionAmount);
    event LogRefund(address sender, uint depositedAmount);

    // NOTE: the contract creator is the exchange shop (Carol), as she needs to set the
    // currency rate and commission % before any client decides to use their services.
    function Remittance(uint _wei2CurrencyRate, uint _commissionPercentage, uint _defaultDuration)
        public
    {
        owner = msg.sender;
        defaultDuration = _defaultDuration;
        wei2CurrencyRate = _wei2CurrencyRate;
        commissionPercentage = _commissionPercentage;
    }

    // This is the function anyone can use to create new remittance instructions - including the
    // passwords intended for the beneficiary and the exchange shop to unlock the funds - and to
    // deposit the funds themselves.
    function deposit(bytes32 _beneficiaryPasswordHash, bytes32 _exchangePasswordHash)
        public
        payable
        returns(bool)
    {
        // no pre-existing instruction and deposit for this sender exists
        require(remittanceInstructions[msg.sender].depositedAmount == 0);
        // need to put some money in it
        require(msg.value > 0);

        remittanceInstructions[msg.sender].sender = msg.sender;
        remittanceInstructions[msg.sender].expirationBlock = block.number + defaultDuration;
        remittanceInstructions[msg.sender].depositedAmount = msg.value;
        remittanceInstructions[msg.sender].beneficiaryPasswordHash = _beneficiaryPasswordHash;
        remittanceInstructions[msg.sender].exchangePasswordHash = _exchangePasswordHash;
        LogDeposit(msg.sender, msg.value);
        return(true);
    }

    // This function credits the exchange shop with the whole value of the contract, and returns in
    // LogTransfer the information required to pay the beneficiary in local currency, minus the
    // commission.
    // It needs to be called by the exchange shop, with the beneficiary being present, so that they
    // can input both their passwords as they were assigned to them by the sender.
    // It has to be called by the exchange shop as it is fair that they pay for the gas, as they
    // get a commission compensating them for the service.
    function transfer(address senderAddress, string _beneficiaryPassword, string _exchangePassword)
        public
        returns(bool success)
    {
        // only the exchange shop can trigger the transfer...
        require(msg.sender == owner);
        // ... if there is money in it...
        require(remittanceInstructions[senderAddress].depositedAmount > 0);
        // .. if the passwords are correct...
        require((remittanceInstructions[senderAddress].beneficiaryPasswordHash == keccak256(_beneficiaryPassword)) && (remittanceInstructions[senderAddress].exchangePasswordHash == keccak256(_exchangePassword)));
        // ... and if the available time has not expired
        require(block.number <= remittanceInstructions[msg.sender].expirationBlock);

        uint depositedAmount = remittanceInstructions[msg.sender].depositedAmount;
        remittanceInstructions[msg.sender].depositedAmount = 0;
        uint commissionAmount = depositedAmount * commissionPercentage / uint(100);
        uint localCurrencyAmount = (depositedAmount - commissionAmount) * wei2CurrencyRate;
        owner.transfer(depositedAmount);
        LogTransfer(senderAddress, localCurrencyAmount, commissionAmount);
        return(true);
    }

    // If the beneficiary and the exchange shop use their passwords correctly but the transfer of
    // the funds to the shop fails, they should not use the passwords again and the only action
    // possible is for the sender to be refunded.
    function refund()
        public
        returns(bool)
    {
        // only the sender can ask for a refund of course, and we can tell if active remittance
        // instructions exist for her address
        require(remittanceInstructions[msg.sender].depositedAmount > 0);
        // ... and the available time for the beneficiary and exchange shop has expired
        require(block.number > remittanceInstructions[msg.sender].expirationBlock);

        uint depositedAmount = remittanceInstructions[msg.sender].depositedAmount;
        remittanceInstructions[msg.sender].depositedAmount = 0;
        msg.sender.transfer(depositedAmount);
        LogRefund(msg.sender, depositedAmount);
        return(true);
    }

}
