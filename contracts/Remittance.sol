pragma solidity ^0.4.15;

// Note: this contract allows only one remittance instruction per beneficiary password

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
        address senderAddress;
        uint expirationBlock; // the latest possible block no. to transfer
        uint depositedAmount; // Wei
        uint commissionAmount; // Wei
        uint localCurrencyAmount; // local currency
        bytes32 exchangePasswordHash;
    }
    // the hash of the beneficiary's password is used as each instruction's location in the
    // mapping
    mapping (bytes32 => RemittanceInstruction) public remittanceInstructions;

    // The beneficiary's password hash is issued as part of all events because it allows the
    // unambiguous identification of the remittance instruction the events are describing
    event LogDeposit(bytes32 beneficiaryPasswordHash, address sender, uint depositedAmount);
    event LogTransfer(bytes32 beneficiaryPasswordHash, uint localCurrencyAmount, uint commissionAmount);
    event LogRefund(bytes32 beneficiaryPasswordHash, uint depositedAmount);

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
        // no pre-existing instruction for this beneficiary password hash exists
        require(remittanceInstructions[_beneficiaryPasswordHash].depositedAmount == 0);
        // need to put some money in it
        require(msg.value > 0);

        remittanceInstructions[_beneficiaryPasswordHash].senderAddress = msg.sender;         remittanceInstructions[_beneficiaryPasswordHash].expirationBlock = block.number + defaultDuration;
        remittanceInstructions[_beneficiaryPasswordHash].depositedAmount = msg.value;
        remittanceInstructions[_beneficiaryPasswordHash].exchangePasswordHash = _exchangePasswordHash;
        LogDeposit(_beneficiaryPasswordHash, msg.sender, msg.value);
        return(true);
    }

    // This function credits the exchange shop with the whole value of the contract, and returns in
    // LogTransfer the information required to pay the beneficiary in local currency, minus the
    // commission.
    // It needs to be called by the exchange shop, with the beneficiary being present, so that they
    // can input both their passwords as they were assigned to them by the sender.
    // It has to be called by the exchange shop as it is fair that they pay for the gas, as they
    // get a commission compensating them for the service.
    function transfer(string _beneficiaryPassword, string _exchangePassword)
        public
        returns(bool success)
    {
        // This is the address in remittanceInstructions the hash where the RemittanceInstruction
        // struct is presumed to be; the beneficiary password needs being right to find it!
        bytes32 remittanceInstructionAddress = keccak256(_beneficiaryPassword);

        // only the exchange shop can trigger the transfer...
        require(msg.sender == owner);
        // ... if the remittance instruction exists for this beneficiary password hash, and there
        // is money in it...
        require(remittanceInstructions[remittanceInstructionAddress].depositedAmount > 0);
        // .. if the exchange password is correct, too...
        require(remittanceInstructions[remittanceInstructionAddress].exchangePasswordHash == keccak256(_exchangePassword));
        // ... and if the available time has not expired
        require(block.number <= remittanceInstructions[remittanceInstructionAddress].expirationBlock);

        uint depositedAmount = remittanceInstructions[remittanceInstructionAddress].depositedAmount;
        remittanceInstructions[remittanceInstructionAddress].depositedAmount = 0;
        uint commissionAmount = depositedAmount * commissionPercentage / uint(100);
        uint localCurrencyAmount = (depositedAmount - commissionAmount) * wei2CurrencyRate;
        owner.transfer(depositedAmount);
        LogTransfer(remittanceInstructionAddress, localCurrencyAmount, commissionAmount);
        return(true);
    }

    // If the beneficiary and the exchange shop use their passwords correctly but the transfer of
    // the funds to the shop fails, they should not use the passwords again and the only action
    // possible is for the sender to be refunded.
    function refund(bytes32 _beneficiaryPasswordHash)
        public
        returns(bool)
    {
        // only the sender can ask for a refund...
        require(msg.sender == remittanceInstructions[_beneficiaryPasswordHash].senderAddress);
        // ... while the beneficiary password's hash allows to identify the specific instruction,
        // and if there is money in it
        require(remittanceInstructions[_beneficiaryPasswordHash].depositedAmount > 0);
        // ... finally, the available time for the beneficiary and exchange shop must have expired
        require(block.number > remittanceInstructions[_beneficiaryPasswordHash].expirationBlock);

        uint depositedAmount = remittanceInstructions[_beneficiaryPasswordHash].depositedAmount;
        remittanceInstructions[_beneficiaryPasswordHash].depositedAmount = 0;
        msg.sender.transfer(depositedAmount);
        LogRefund(_beneficiaryPasswordHash, depositedAmount);
        return(true);
    }

}
