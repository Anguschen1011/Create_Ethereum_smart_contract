// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RentAgreement {
    // Key parameters in the contract
    address public landlord; // Landlord's address
    address public tenant; // Tenant's address
    uint256 public rentAmount; // Monthly rent amount (in Wei)
    uint256 public depositAmount; // Deposit amount (in Wei)
    uint256 public utilityAmount; // Monthly utility fee amount (in Wei)
    uint256 public rentDueDate; // Rent due date
    uint256 public leaseEndDate; // Lease end date (timestamp)
    bool public depositPaid; // Whether the deposit has been paid
    bool public contractTerminated; // Variable indicating if the contract has been terminated

    // Events to record important activities in the contract
    event RentPaid(address indexed tenant, uint256 amount); // Rent payment event
    event UtilityPaid(address indexed tenant, uint256 amount); // Utility payment event
    event DepositPaid(address indexed tenant, uint256 amount); // Deposit payment event
    event MaintenanceRequested(address indexed tenant, string request); // Maintenance request event
    event LeaseTerminated(address indexed tenant); // Lease termination event
    event Withdrawal(address indexed landlord, uint256 amount); // Withdrawal event

    // Modifiers to restrict access to certain functions
    modifier onlyLandlord() {
        require(msg.sender == landlord, "Only the landlord can call this function");
        _;
    }

    modifier onlyTenant() {
        require(msg.sender == tenant, "Only the tenant can call this function");
        _;
    }

    // Constructor to initialize contract parameters
    constructor(
        address _tenant,
        uint256 _rentAmountInETH,
        uint256 _depositAmountInETH,
        uint256 _leaseDurationYears,
        uint256 _leaseDurationMonths,
        uint256 _leaseDurationDays
    ) {
        landlord = msg.sender; // Set the landlord as the contract deployer
        tenant = _tenant; // Set the tenant's wallet address
        rentAmount = _rentAmountInETH * 1 ether; // Set the monthly rent amount (convert ETH to Wei)
        depositAmount = _depositAmountInETH * 1 ether; // Set the deposit amount (convert ETH to Wei)

        // Calculate the lease duration
        uint256 leaseDurationInSeconds = (
            (_leaseDurationYears * 365 * 24 * 60 * 60) +
            (_leaseDurationMonths * 30 * 24 * 60 * 60) +
            (_leaseDurationDays * 24 * 60 * 60)
        );

        rentDueDate = block.timestamp + 30 days; // Set the first rent due date
        leaseEndDate = block.timestamp + leaseDurationInSeconds; // Set the lease end date
    }

    // Tenant pays the rent
    function payRent() public payable onlyTenant {
        require(msg.value == rentAmount, "Incorrect rent amount"); // Check if the payment amount is correct
        require(block.timestamp <= rentDueDate, "Rent is overdue"); // Check if the rent is overdue
        rentDueDate += 30 days; // Update the next rent due date
        emit RentPaid(msg.sender, msg.value); // Trigger rent payment event
    }

    // Tenant pays the utility fee
    function payUtility() public payable onlyTenant {
        require(msg.value == utilityAmount, "Incorrect utility amount"); // Check if the payment amount is correct
        require(block.timestamp <= rentDueDate, "Utility payment is overdue"); // Check if the utility payment is overdue
        emit UtilityPaid(msg.sender, msg.value); // Trigger utility payment event
    }

    // Tenant pays the deposit
    function payDeposit() public payable onlyTenant {
        require(msg.value == depositAmount, "Incorrect deposit amount"); // Check if the payment amount is correct
        require(!depositPaid, "Deposit already paid"); // Check if the deposit has already been paid
        depositPaid = true; // Set the deposit paid flag
        emit DepositPaid(msg.sender, msg.value); // Trigger deposit payment event
    }

    // Landlord sets the monthly utility fee amount
    function setUtilityAmount(uint256 _utilityAmountInETH) public onlyLandlord {
        utilityAmount = _utilityAmountInETH * 1 ether; // Update the utility fee amount (convert ETH to Wei)
    }

    // Tenant submits a maintenance request
    function requestMaintenance(string memory request) public onlyTenant {
        emit MaintenanceRequested(msg.sender, request); // Trigger maintenance request event
    }

    // Landlord terminates the lease
    function terminateContract() public {
        require(msg.sender == landlord, "Only landlord can terminate contract");
        require(!contractTerminated, "Contract already terminated");

        if (depositPaid) {
            payable(tenant).transfer(depositAmount);
        }

        contractTerminated = true;
        emit LeaseTerminated(tenant);
    }

    function checkAndTerminateContract() public {
        require(!contractTerminated, "Contract already terminated");

        // Check if the contract end date has been reached
        if (block.timestamp >= leaseEndDate) {
            if (depositPaid) {
                payable(tenant).transfer(depositAmount);
            }

            contractTerminated = true;
            emit LeaseTerminated(tenant);
        }
    }

    // View the total amount due (rent + utility fee)
    function getTotalDue() public view returns (uint256) {
        return (rentAmount + utilityAmount) / 1 ether; // Return the total amount due
    }

    // Withdraw the balance in the contract (excluding the deposit)
    function withdrawBalance() public onlyLandlord {
        uint256 balanceToWithdraw = address(this).balance - depositAmount; // Calculate the amount that can be withdrawn (excluding the deposit)
        require(balanceToWithdraw > 0, "No balance to withdraw"); // Check if there is a balance to withdraw
        payable(landlord).transfer(balanceToWithdraw); // Transfer the amount to the landlord's address
        emit Withdrawal(landlord, balanceToWithdraw); // Trigger withdrawal event
    }

    // View the contract balance
    function getBalance() public view returns (uint256) {
        return address(this).balance / 1 ether; // Return the contract balance
    }

    function getRentDueDate() public view returns (uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute, uint8 second) {
        // Calculate year, month, day, hour, minute, second
        year = uint16((rentDueDate / (60 * 60 * 24 * 365)) + 1970);
        uint256 secondsLeft = rentDueDate % (60 * 60 * 24 * 365);
        month = uint8((secondsLeft / (60 * 60 * 24 * 30)) % 12 + 1);
        secondsLeft %= (60 * 60 * 24 * 30);
        day = uint8((secondsLeft / (60 * 60 * 24)) % 30 + 1);
        secondsLeft %= (60 * 60 * 24);
        hour = uint8((secondsLeft / (60 * 60)) % 24);
        secondsLeft %= (60 * 60);
        minute = uint8((secondsLeft / 60) % 60);
        second = uint8(secondsLeft % 60);
    }
    
    function getLeaseEndDate() public view returns (uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute, uint8 second){
        // Calculate year, month, day, hour, minute, second
        year = uint16((leaseEndDate / (60 * 60 * 24 * 365)) + 1970);
        uint256 secondsLeft = leaseEndDate % (60 * 60 * 24 * 365);
        month = uint8((secondsLeft / (60 * 60 * 24 * 30)) % 12 + 1);
        secondsLeft %= (60 * 60 * 24 * 30);
        day = uint8((secondsLeft / (60 * 60 * 24)) % 30 + 1);
        secondsLeft %= (60 * 60 * 24);
        hour = uint8((secondsLeft / (60 * 60)) % 24);
        secondsLeft %= (60 * 60);
        minute = uint8((secondsLeft / 60) % 60);
        second = uint8(secondsLeft % 60);
    }
}
