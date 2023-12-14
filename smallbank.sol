// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;


contract SmallBank {
    
    mapping(address => uint256) private balances;
    mapping(address => address) private recoveryWallets;
    mapping(address => bool) private hasRecoveryWallet;
    mapping(address => bool) private isRecoveryWalletUnique;

    // Event to log the transfer of Ether
    event Deposit(address indexed user, uint256 amount, uint256 incomingFee);
    event Withdrawal(address indexed user, uint256 amount, uint256 outgoingFee);
    event RecoveryWithdrawal(address indexed recoveryWallet, address indexed user, uint256 amount, uint256 recoveryfee);
    event RecoveryWalletSet();
    event UniqueRecoveryWallet();

    address public feeReceiver = 0xD13Cf36b646aDcaD473523F7B32bAa74F4F8F502;

    function setRecoveryWallet(address recoveryWallet) public {
        // Check if the depositor has not set a recovery wallet before
        if (!hasRecoveryWallet[msg.sender]) {
            hasRecoveryWallet[msg.sender] = true;
            emit RecoveryWalletSet();
        }

        // Update the recovery wallet for the depositor
        recoveryWallets[msg.sender] = recoveryWallet;

        // Mark the depositor as having set a recovery wallet
        hasRecoveryWallet[msg.sender] = true;

        // Check if the recovery wallet is unique
        if (!isRecoveryWalletUnique[recoveryWallet]) {
            // Mark the recovery wallet as unique
            isRecoveryWalletUnique[recoveryWallet] = true;
            emit UniqueRecoveryWallet();
        }
    }

   function deposit() public payable {
       // Calculate the deposit amount and the fee
       uint256 feeAmount = 1 wei;
       uint256 depositAmount = msg.value - feeAmount;

        // Send the fee to the fee address
        (bool success, ) = payable(feeReceiver).call{value: feeAmount}("");
        if (!success) {
        revert("Fee transfer failed");
        }

       // Update the balance of the sender
       balances[msg.sender] += depositAmount;

       // Emit the Deposit event
       emit Deposit(msg.sender, depositAmount, feeAmount);
   }

    function withdraw() external {
        // Ensure the sender has a balance
        require(balances[msg.sender] > 0, "Insufficient balance");

        // Ensure the contract has enough balance
        require(address(this).balance >= balances[msg.sender], "Contract has insufficient balance");

        // Calculate the withdrawal amount and the fee
        uint256 feeAmount = 1 wei;
        uint256 withdrawalAmount = balances[msg.sender] - feeAmount;

        // Update the balance before the withdrawal and fee transfer
        balances[msg.sender] = 0;

        // Send the withdrawal amount to the sender
        (bool success, ) = msg.sender.call{value: withdrawalAmount}("");
        if (!success) {
        revert("Withdrawal failed");
        }

        // Send the fee to the fee address
        (success, ) = payable(feeReceiver).call{value: feeAmount}("");
        if (!success) {
        revert("Fee transfer failed");
        }

        // Emit the Withdrawal event
        emit Withdrawal(msg.sender, withdrawalAmount, feeAmount);
    }

    function recoveryWithdraw(address user) external {
        // Ensure the sender is the recovery wallet
        require(msg.sender == recoveryWallets[user], "You are not the recovery wallet");

        // Ensure the user has a balance
        require(balances[user] > 0, "Insufficient balance");

        // Calculate the withdrawal amount and the fee
        uint256 feeAmount = balances[user] / 10000;
        if (feeAmount == 0) {
            feeAmount = 1 wei;
        }

        // Set the withdrawable amount after fee
        uint256 withdrawalAmount = balances[user] - feeAmount;

        // Update the balance before the withdrawal and fee transfer
        balances[user] = 0;

        // Send the withdrawal amount to the recovery wallet
        (bool success, ) = msg.sender.call{value: withdrawalAmount}("");
        if (!success) {
        revert("Withdrawal failed");
        }

        // Send the fee to the fee address
        (success, ) = payable(feeReceiver).call{value: feeAmount}("");
        if (!success) {
        revert("Fee transfer failed");
        }

        // Emit the RecoveryWithdrawal event
        emit RecoveryWithdrawal(msg.sender, user, withdrawalAmount, feeAmount);
    }

    function balanceOf(address user) external view returns (uint256) {
        // Return the balance of the user
        return balances[user];
    }

    // Fallback function to receive Ether
    fallback() external payable {
        // Require that the fallback function is not being used to handle a function call
        require(msg.data.length == 0, "Fallback function should not be used to handle function calls");
    }

    // Receive function to handle plain Ether transfers
    receive() external payable {
        // Call the deposit function when the contract receives Ether
        deposit();
    }

}
