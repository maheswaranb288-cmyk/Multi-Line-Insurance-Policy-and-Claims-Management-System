import { LightningElement, api } from 'lwc';

export default class ClaimKpiTile extends LightningElement {
    @api label;
    @api value;
    @api iconName = 'standard:metrics';
    @api accent = 'brand'; // brand | warning | success

    get tileClass() {
        return `tile tile_${this.accent}`;
    }
}
