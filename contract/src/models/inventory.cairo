use core::array::ArrayTrait;

mod errors {
    const INVENTORY_FULL: felt252 = 'Inventory is full max 30 ';
    const ITEM_NOT_FOUND: felt252 = 'Item not found in inventory';
    const INVALID_ITEM: felt252 = 'Invalid item data';
}

#[derive(Drop, Serde, Clone, Introspect)]
struct InventoryItem {
    player_id: u32,
    token_id: u32,
    quantity: u32,
}

#[derive(Drop, Serde, Clone, Introspect)]
#[dojo::model]
pub struct PlayerInventory {
    #[key]
    pub player_id: u32,
    pub items: Array<InventoryItem>,
    pub max_unique_items: u32,
    pub is_set: bool,
}

#[generate_trait]
impl PlayerInventoryImpl of PlayerInventoryTrait {
    const MAX_UNIQUE_ITEMS: u32 = 30;

    #[inline(always)]
    fn new(player_id: u32) -> PlayerInventory {
        PlayerInventory {
            player_id,
            items: ArrayTrait::new(),
            max_unique_items: Self::MAX_UNIQUE_ITEMS,
            is_set: true,
        }
    }

    #[inline(always)]
    fn add_item_to_inventory(ref self: PlayerInventory, token_id: u32, quantity: u32) -> bool {
        if quantity <= 0 || token_id <= 0 {
            return false;
        }
        let mut item_index: Option<u32> = Option::None;
        let mut i: u32 = 0;

        loop {
            if i >= self.items.len().try_into().unwrap() {
                break;
            }

            let item = self.items.at(i.try_into().unwrap());
            if item.token_id == @token_id {
                item_index = Option::Some(i);
                break;
            }
            i += 1;
        };

        match item_index {
            Option::Some(index) => {
                let mut item = self.items.at(index.try_into().unwrap()).clone();
                item.quantity += quantity;

                let mut new_items = ArrayTrait::new();
                let mut j: u32 = 0;
                loop {
                    if j >= self.items.len().try_into().unwrap() {
                        break;
                    }
                    if j != index {
                        new_items.append(self.items.at(j.try_into().unwrap()).clone());
                    }
                    j += 1;
                };

                new_items.append(item);
                self.items = new_items;
                true
            },
            Option::None => {
                if self.items.len() >= self.max_unique_items.try_into().unwrap() {
                    return false;
                }

                let new_item = InventoryItem { player_id: self.player_id, token_id, quantity };
                self.items.append(new_item);
                true
            },
        }
    }

    #[inline(always)]
    fn get_inventory(self: @PlayerInventory) -> Array<InventoryItem> {
        self.items.clone()
    }
}
#[cfg(test)]
mod tests {
    use super::PlayerInventoryImpl;
    use super::PlayerInventoryTrait;

    #[test]
    fn test_new_inventory() {
        let inventory = PlayerInventoryImpl::new(123);
        assert(inventory.player_id == 123, 'Wrong player ID');
        assert(inventory.items.len() == 0, 'New inventory should be empty');
        assert(inventory.max_unique_items == 30, 'Max items should be 30');
        assert(inventory.is_set, 'Inventory should be initialized');
    }

    #[test]
    fn test_add_new_item() {
        let mut inventory = PlayerInventoryImpl::new(1);
        let result = inventory.add_item_to_inventory(101, 5);

        assert(result, 'Should add new item succe');
        assert(inventory.items.len() == 1, 'Should have 1 item');
        assert(
            inventory.items.at(0).token_id == @101 && inventory.items.at(0).quantity == @5,
            'Item data should match',
        );
    }

    #[test]
    fn test_update_existing_item() {
        let mut inventory = PlayerInventoryImpl::new(1);

        // First add
        inventory.add_item_to_inventory(101, 5);
        // Second add - should update quantity
        let result = inventory.add_item_to_inventory(101, 3);

        assert(result, 'Should update existing item');
        assert(inventory.items.len() == 1, 'Should still have 1 unique item');
        assert(inventory.items.at(0).quantity == @8, 'Quantity should be updated');
    }

    #[test]
    fn test_max_unique_items_limit() {
        let mut inventory = PlayerInventoryImpl::new(1);

        // Add 30 unique items
        let mut i = 0;
        loop {
            if i >= 30 {
                break;
            }
            assert(inventory.add_item_to_inventory(i + 100, 1), 'Should add unique items');
            i += 1;
        };

        // Try to add 31st item
        let result = inventory.add_item_to_inventory(200, 1);
        assert(!result, 'Should reject 31st unique item');
        assert(inventory.items.len() == 30, 'Should still have 30 items');
    }

    #[test]
    fn test_high_quantity_same_item() {
        let mut inventory = PlayerInventoryImpl::new(1);

        // Add large quantity of same item
        assert(inventory.add_item_to_inventory(101, 1000), 'Should allow high quantity');
        assert(inventory.add_item_to_inventory(101, 500), 'Should allow more quantity');

        assert(inventory.items.len() == 1, 'Should count as one unique item');
        assert(inventory.items.at(0).quantity == @1500, 'Quantity should accumulate');
    }

    #[test]
    fn test_multiple_players() {
        let mut inventory1 = PlayerInventoryImpl::new(1);
        let mut inventory2 = PlayerInventoryImpl::new(2);

        inventory1.add_item_to_inventory(101, 5);
        inventory2.add_item_to_inventory(101, 10);

        assert(
            inventory1.items.at(0).quantity == @5 && inventory2.items.at(0).quantity == @10,
            'Players should sep inventories',
        );
    }

    #[test]
    fn test_zero_quantity() {
        let mut inventory = PlayerInventoryImpl::new(1);
        let result = inventory.add_item_to_inventory(101, 0);

        assert(!result, 'Should reject zero quantity');
        assert(inventory.items.len() == 0, 'No item should be added');
    }

    #[test]
    fn test_get_inventory_single_item() {
        let mut inventory = PlayerInventoryImpl::new(42);
        inventory.add_item_to_inventory(55, 7);

        let result = PlayerInventoryImpl::get_inventory(@inventory);
        assert(result.len() == 1, 'Should return one item');

        let item = result.at(0);
        assert(*item.token_id == 55_u32, 'Token ID should match');
        assert(*item.quantity == 7_u32, 'Quantity should match');
    }

    #[test]
    fn test_get_inventory_multiple_items() {
        let mut inventory = PlayerInventoryImpl::new(77);
        inventory.add_item_to_inventory(1, 10);
        inventory.add_item_to_inventory(2, 5);
        inventory.add_item_to_inventory(3, 1);

        let result = PlayerInventoryImpl::get_inventory(@inventory);
        assert(result.len() == 3, 'Should return three items');

        let first = result.at(0);
        assert(*first.token_id == 1_u32, 'First item ID mismatch');

        let second = result.at(1);
        assert(*second.token_id == 2_u32, 'Second item ID mismatch');

        let third = result.at(2);
        assert(*third.token_id == 3_u32, 'Third item ID mismatch');
    }
}
