use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn decimals(self: @TContractState) -> u8;

    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;

    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;

}

#[starknet::contract]
pub mod ERC20 {
    use starknet::event::EventEmitter;
    use core::num::traits::Zero;
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry};

    #[storage]
    pub struct Storage {
        balances: Map::<ContractAddress, u256>, // owner -> amount owned
        allowances: Map::<(ContractAddress, ContractAddress), u256>, // owner, spender -> amount
        token_name: ByteArray,
        symbol: ByteArray,
        decimal: u8,
        total_supply: u256,
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval
    }

    #[derive(Drop, starknet::Event)]
    pub struct Transfer {
        #[key]
        pub from: ContractAddress,
        #[key]
        pub to: ContractAddress,
        pub amount: u256
    }

    #[derive(Drop, starknet::Event)]
    pub struct Approval {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        pub value: u256
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_name: ByteArray, symbol: ByteArray) {
        self.token_name.write(token_name);
        self.symbol.write(symbol);
        self.total_supply.write(1000000000000000000);
        self.decimal.write(18);
        self.owner.write(get_caller_address());
    }

    #[abi(embed_v0)]
    pub impl ERC20Impl of super::IERC20<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.token_name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimal.read()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.entry(account).read()
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.entry((owner, spender)).read()
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            assert(!spender.is_zero(), 'Zero address spender');
            assert(!amount.is_zero(), 'Cannot approve 0');
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Zero address caller');
            let caller_balance = self.balances.entry(caller).read();
            assert(caller_balance >= amount, 'Cannot approve past balance');

            self.allowances.entry((caller, spender)).write(self.allowances.entry((caller, spender)).read() + amount);

            self.emit(
                Approval { owner: caller, spender, value: amount }
            );
            true
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            assert(!amount.is_zero(), 'Cannot transfer 0');
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Zero address caller');
            assert(!recipient.is_zero(), 'Zero address recipient');

            let caller_balance = self.balances.entry(caller).read();
            assert(caller_balance >= amount, 'Cannot transfer past balance');

            self.balances.entry(caller).write(self.balances.entry(caller).read() - amount);
            self.balances.entry(recipient).write(self.balances.entry(recipient).read() + amount);

            self.emit(
                Transfer { from: caller, to: recipient, amount }
            );

            true
        }

        fn transfer_from(
            ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool {
            assert(!amount.is_zero(), 'Cannot approve 0');
            assert(!sender.is_zero(), 'Zero address sender');
            assert(!recipient.is_zero(), 'Zero address recipient');
            let spender = get_caller_address();
            assert(!spender.is_zero(), 'Zero address sender');
            let sender_balance = self.balances.entry(sender).read();
            let spender_allowance = self.allowances.entry((sender, spender)).read();

            assert(spender_allowance >= amount, 'Amount exceeds allowance');
            assert(sender_balance >= amount, 'Amount exceeds sender balance');

            self.balances.entry(recipient).write(self.balances.entry(recipient).read() + amount);
            self.balances.entry(sender).write(self.balances.entry(sender).read() - amount);
            self.allowances.entry((sender, spender)).write(self.allowances.entry((sender, spender)).read() - amount);

            self.emit(
                Transfer { from: sender, to: recipient, amount }
            );

            true
        }

        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            assert(!amount.is_zero(), 'Cannot mint 0');
            let prev_supply = self.total_supply.read();
            let prev_balance = self.balances.entry(recipient).read();

            self.total_supply.write(prev_supply + amount);
            self.balances.entry(recipient).write(prev_balance + amount);

            let zero_address: ContractAddress = Zero::zero();

            self.emit(
                Transfer { from: zero_address, to: recipient, amount }
            );

            true
        }
    }
}