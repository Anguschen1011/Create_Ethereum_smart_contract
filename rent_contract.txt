// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RentAgreement {
    // 合約中的關鍵參數
    address public landlord; // 房東地址
    address public tenant; // 租客地址
    uint256 public rentAmount; // 每月房租金額（Wei）
    uint256 public depositAmount; // 保證金金額（Wei）
    uint256 public utilityAmount; // 每月水電費金額（Wei）
    uint256 public rentDueDate; // 房租到期日
    uint256 public leaseEndDate; // 租約結束日期（時間戳）
    bool public depositPaid; // 保證金是否已支付
    bool public contractTerminated; // 添加合約是否已終止的變量

    // 事件，用於記錄合約中的重要活動
    event RentPaid(address indexed tenant, uint256 amount); // 房租支付事件
    event UtilityPaid(address indexed tenant, uint256 amount); // 水電費支付事件
    event DepositPaid(address indexed tenant, uint256 amount); // 保證金支付事件
    event MaintenanceRequested(address indexed tenant, string request); // 維修請求事件
    event LeaseTerminated(address indexed tenant); // 租約終止事件
    event Withdrawal(address indexed landlord, uint256 amount); // 提款事件

    // 修飾符，用於限制某些函數的訪問權限
    modifier onlyLandlord() {
        require(msg.sender == landlord, "Only the landlord can call this function");
        _;
    }

    modifier onlyTenant() {
        require(msg.sender == tenant, "Only the tenant can call this function");
        _;
    }

    // 構造函數，初始化合約參數
    constructor(
        address _tenant,
        uint256 _rentAmountInETH,
        uint256 _depositAmountInETH,
        uint256 _leaseDurationYears,
        uint256 _leaseDurationMonths,
        uint256 _leaseDurationDays
    ) {
        landlord = msg.sender; // 設置房東為合約部署者
        tenant = _tenant; // 設置租客錢包地址
        rentAmount = _rentAmountInETH * 1 ether; // 設置每月房租金額（ETH轉換為Wei）
        depositAmount = _depositAmountInETH * 1 ether; // 設置保證金金額（ETH轉換為Wei）

        // 計算租賃期限
        uint256 leaseDurationInSeconds = (
            (_leaseDurationYears * 365 * 24 * 60 * 60) +
            (_leaseDurationMonths * 30 * 24 * 60 * 60) +
            (_leaseDurationDays * 24 * 60 * 60)
        );

        rentDueDate = block.timestamp + 30 days; // 設置第一個房租到期日
        leaseEndDate = block.timestamp + leaseDurationInSeconds; // 設置租約結束日期
    }

    // 租客支付房租
    function payRent() public payable onlyTenant {
        require(msg.value == rentAmount, "Incorrect rent amount"); // 檢查支付金額是否正確
        require(block.timestamp <= rentDueDate, "Rent is overdue"); // 檢查房租是否逾期
        rentDueDate += 30 days; // 更新下一個房租到期日
        emit RentPaid(msg.sender, msg.value); // 觸發房租支付事件
    }

    // 租客支付水電費
    function payUtility() public payable onlyTenant {
        require(msg.value == utilityAmount, "Incorrect utility amount"); // 檢查支付金額是否正確
        require(block.timestamp <= rentDueDate, "Utility payment is overdue"); // 檢查水電費是否逾期
        emit UtilityPaid(msg.sender, msg.value); // 觸發水電費支付事件
    }

    // 租客支付保證金
    function payDeposit() public payable onlyTenant {
        require(msg.value == depositAmount, "Incorrect deposit amount"); // 檢查支付金額是否正確
        require(!depositPaid, "Deposit already paid"); // 檢查保證金是否已支付
        depositPaid = true; // 設置保證金已支付標記
        emit DepositPaid(msg.sender, msg.value); // 觸發保證金支付事件
    }

    // 房東設置每月的水電費金額
    function setUtilityAmount(uint256 _utilityAmountInETH) public onlyLandlord {
        utilityAmount = _utilityAmountInETH * 1 ether; // 更新水電費金額（ETH轉換為Wei）
    }

    // 租客提交維修請求
    function requestMaintenance(string memory request) public onlyTenant {
        emit MaintenanceRequested(msg.sender, request); // 觸發維修請求事件
    }

    // 房東終止租約
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

        // 檢查是否已經到達合約的終止日期
        if (block.timestamp >= leaseEndDate) {
            if (depositPaid) {
                payable(tenant).transfer(depositAmount);
            }

            contractTerminated = true;
            emit LeaseTerminated(tenant);
        }
    }

    // 查看總應付金額（房租 + 水電費）
    function getTotalDue() public view returns (uint256) {
        return (rentAmount + utilityAmount) / 1 ether; // 返回總應付金額
    }

    // 提取合約中的餘額（不包括保證金）
    function withdrawBalance() public onlyLandlord {
        uint256 balanceToWithdraw = address(this).balance - depositAmount; // 計算可提取的金額（扣除保證金）
        require(balanceToWithdraw > 0, "No balance to withdraw"); // 檢查可提取的金額是否大於 0
        payable(landlord).transfer(balanceToWithdraw); // 將金額轉移到房東地址
        emit Withdrawal(landlord, balanceToWithdraw); // 觸發提款事件
    }

    // 查看合約餘額
    function getBalance() public view returns (uint256) {
        return address(this).balance / 1 ether; // 返回合約餘額
    }

    function getRentDueDate() public view returns (uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute, uint8 second) {
        // 計算年、月、日、时、分、秒
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
        // 計算年、月、日、时、分、秒
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