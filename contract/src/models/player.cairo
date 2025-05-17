use starknet::{ContractAddress, contract_address_const};
use core::num::traits::zero::Zero;

#[derive(Copy, Drop, Serde, IntrospectPacked, Debug, PartialEq)]
#[dojo::model]
pub struct Player {
    #[key]
    pub owner: ContractAddress,
    pub name: felt252,
    pub class: felt252,
    pub level: u8,
    pub health: u16,
    pub mana: u16,
}

pub mod errors {
    pub const ALREADY_EXISTS: felt252 = 'Player already exists';
    pub const DOES_NOT_EXIST: felt252 = 'Player not found';
}

pub fn initialize_player(owner: ContractAddress, name: felt252, class: felt252) -> Player {
    Player {
        owner,
        name,
        class,
        level: 1_u8,
        health: 100_u16,
        mana: 50_u16,
    }
}

#[generate_trait]
pub impl PlayerImpl of PlayerTrait {
    #[inline(always)]
    fn level_up(ref self: Player) {
        self.level += 1_u8;
        self.health += 10_u16;
        self.mana += 5_u16;
    }
}

pub impl ZeroablePlayer of Zero<Player> {
    #[inline(always)]
    fn zero() -> Player {
        Player {
            owner: contract_address_const::<0>(),
            name: '0',
            class: '0',
            level: 0_u8,
            health: 0_u16,
            mana: 0_u16,
        }
    }

    #[inline(always)]
    fn is_zero(self: @Player) -> bool {
        *self.level == 0_u8 && *self.health == 0_u16 && *self.mana == 0_u16
    }

    #[inline(always)]
    fn is_non_zero(self: @Player) -> bool {
        !Self::is_zero(self)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use starknet::contract_address_const;

    #[test]
    fn test_initialize_player() {
        let owner = contract_address_const::<0x111>();
        let name = 'Alice';
        let class = 'Mage';
        let p = initialize_player(owner, name, class);
        assert(p.owner == owner, 'owner mismatch');
        assert(p.name == name, 'name mismatch');
        assert(p.class == class, 'class mismatch');
        assert(p.level == 1_u8, 'level mismatch');
        assert(p.health == 100_u16, 'health mismatch');
        assert(p.mana == 50_u16, 'mana mismatch');
    }

    #[test]
    fn test_level_up() {
        let owner = contract_address_const::<0x222>();
        let mut p = initialize_player(owner, 'Bob', 'Warrior');
        PlayerImpl::level_up(ref p);
        assert(p.level == 2_u8, 'level not increased');
        assert(p.health == 110_u16, 'health not increased');
        assert(p.mana == 55_u16, 'mana not increased');
    }

    #[test]
    fn test_zero_player() {
        let p = ZeroablePlayer::zero();
        assert(ZeroablePlayer::is_zero(@p), 'Should be zero');
        assert(!ZeroablePlayer::is_non_zero(@p), 'Should not be non-zero');
    }

    #[test]
    fn test_non_zero_player() {
        let p = initialize_player(contract_address_const::<0x333>(), 'C', 'Fighter');
        assert(!ZeroablePlayer::is_zero(@p), 'Should not be zero');
        assert(ZeroablePlayer::is_non_zero(@p), 'Should be non-zero');
    }
}
