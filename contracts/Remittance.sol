pragma solidity ^0.4.15;

// This is a first basic implementation of the problem. Situations that still need being managed
// are:
// - Bob and Carol never meet and Alice's money is frozen in the contract: this can be solved
//   by allowing Alice to get the money back after a certain time (blocks)

// TODO
// - stretch goals
// - Rob's suggestion at https://b9labacademy.slack.com/archives/G7C3K7VK6/p1512865360000038?thread_ts=1512860367.000041&cid=G7C3K7VK6

contract Remittance {

    address public owner; // that's the Carol's exchange shop address
    // the exchange rate is expressed as an integer, e.g. 3 means 1 Wei = 3 units of currency
    uint public wei2CurrencyRate;
    // commission percentage is expressed as an integer, e.g. 2 for 2%
    uint public commissionPercentage;

    struct RemittanceInstruction {
        address sender; // Alice
        uint depositedAmount; // Wei
        uint commissionAmount; // Wei
        uint localCurrencyAmount; // local currency
        bytes32 beneficiaryPasswordHash;
        bytes32 exchangePasswordHash;
        // these are the statuses the instruction goes through
        //     true if the sender has deposited money
               bool active;
        //     true if the transfer to the exchange shop was attepted at least once
               bool attemptedTransfer;
        //     true if the above transfer was successful
               bool successfulTransfer;
        //     true if refund was attempted and successful
               bool refunded;
    }
    mapping (address => RemittanceInstruction) public remittanceInstructions;

    event LogDeposit(address sender, uint depositedAmount);
    event LogSuccessfulTransfer(address sender, uint localCurrencyAmount, uint commissionAmount);
    event LogFailedTransfer(address sender);
    event LogRefund(address sender, uint depositedAmount);

    // NOTE: the contract creator is the exchange shop (Carol), as she needs to set the
    // currency rate and commission % before any client decides to use their services.
    function Remittance(uint _wei2CurrencyRate, uint _commissionPercentage)
        public
    {
        owner = msg.sender;
        wei2CurrencyRate = _wei2CurrencyRate;
        commissionPercentage = _commissionPercentage;
    }

    // This is the function anyone can use to create new remittance instructions - including the
    // passwords intended for the beneficiary and the exchange shop to unlock the funds - and to
    // deposit the funds themselves.
    //
    function deposit(bytes32 _beneficiaryPasswordHash, bytes32 _exchangePasswordHash)
        public
        payable
        returns(bool)
    {
        // no pre-existing instruction and deposit for this sender exists
        require(!remittanceInstructions[msg.sender].active);
        // b*tch better have my money
        require(msg.value > 0);

        remittanceInstructions[msg.sender].active = true;
        remittanceInstructions[msg.sender].sender = msg.sender;
        remittanceInstructions[msg.sender].beneficiaryPasswordHash = _beneficiaryPasswordHash;
        remittanceInstructions[msg.sender].exchangePasswordHash = _exchangePasswordHash;
        remittanceInstructions[msg.sender].depositedAmount = msg.value;
        remittanceInstructions[msg.sender].commissionAmount = msg.value * commissionPercentage / uint(100);
        remittanceInstructions[msg.sender].localCurrencyAmount = (remittanceInstructions[msg.sender].depositedAmount - remittanceInstructions[msg.sender].commissionAmount) * wei2CurrencyRate;
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
    // Note: because the passwords are visible in the transaction payload, they should not be used
    //       more than once. Hence, if transferring the money to the exchange shop fails, the whole
    //       operation needs being cancelled, and the sender enabled to get a refund.
    function transfer(address senderAddress, string _beneficiaryPassword, string _exchangePassword)
        public
        returns(bool success)
    {
        // only the exchange shop can trigger the transfer...
        require(msg.sender == owner);
        // ... if the specified instruction actually exists and is active...
        require(remittanceInstructions[senderAddress].active);
        // NOTE: no need to check that there's money in it: it could not be active otherwise
        // require(remittanceInstructions[senderAddress].depositedAmount > 0);
        // ... if transfer not attempted yet...
        require(!remittanceInstructions[senderAddress].attemptedTransfer);
        // .. and if the passwords are correct
        require((remittanceInstructions[senderAddress].beneficiaryPasswordHash == keccak256(_beneficiaryPassword)) && (remittanceInstructions[senderAddress].exchangePasswordHash == keccak256(_exchangePassword)));

        // TODO: I don't want this to be reverted if the transfer fails!!!
        remittanceInstructions[senderAddress].attemptedTransfer = true;
        success = owner.send(remittanceInstructions[senderAddress].depositedAmount);
        if (!success) {
            LogFailedTransfer(senderAddress);
            return(false);
        }
        // enable the sender to create new instructions, as the transfer has succeeded
        remittanceInstructions[senderAddress].active = false;
        LogSuccessfulTransfer(
            senderAddress,
            remittanceInstructions[senderAddress].localCurrencyAmount,
            remittanceInstructions[senderAddress].commissionAmount
        );
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
        require(remittanceInstructions[msg.sender].active);
        // ... and a previous transfer to the exchange shop must have been attempted and failed
        require(remittanceInstructions[msg.sender].attemptedTransfer && !remittanceInstructions[msg.sender].successfulTransfer);
        // ... and refund was not attempted before
        require(!remittanceInstructions[msg.sender].refunded);

        // prevent re-entrance
        remittanceInstructions[msg.sender].refunded = true;
        // enable the sender to create new instructions if the refund is successful
        remittanceInstructions[msg.sender].active = false;
        msg.sender.transfer(remittanceInstructions[msg.sender].depositedAmount);
        LogRefund(msg.sender, remittanceInstructions[msg.sender].depositedAmount);
        return(true);
    }

}
