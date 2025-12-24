#[starknet::contract]
pub mod LPToken {
    use ERC20Component::InternalTrait;
    use openzeppelin::token::erc20::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::{ContractAddress, get_contract_address};
    use uniswap_v2::lp_token::ilp_token::ILPToken;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, name: ByteArray, symbol: ByteArray) {
        // let name = "LPToken";
        // let symbol = "LPT";
        self.erc20.initializer(name, symbol);
    }

    #[abi(embed_v0)]
    pub impl LPTokenImpl of ILPToken<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.erc20.mint(recipient, amount);
        }

        fn burn(ref self: ContractState, sender: ContractAddress, amount: u256) {
            self.erc20._spend_allowance(sender, get_contract_address(), amount);
            self.erc20.burn(sender, amount);
        }

        fn get_total_supply(self: @ContractState) -> u256 {
            self.erc20.total_supply()
        }
    }
}
