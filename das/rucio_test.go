package das

import (
	"testing"

	"github.com/dmwm/das2go/dasql"
	"github.com/dmwm/das2go/mongo"
	"gopkg.in/mgo.v2/bson"
)

func TestBlock4DatasetEncodesRucioDIDName(t *testing.T) {
	dmap := mongo.DASRecord{
		"system": "rucio",
		"urn":    "block4dataset",
		"url":    "https://cms-rucio.cern.ch/dids/cms/",
		"expire": 3600,
		"lookup": "block",
		"das_map": []interface{}{
			map[string]interface{}{"das_key": "dataset", "rec_key": "dataset.name"},
			map[string]interface{}{"das_key": "block", "rec_key": "block.name"},
		},
	}
	query := dasql.DASQuery{Spec: bson.M{"dataset": "/Primary/Processed/TIER"}}
	want := "https://cms-rucio.cern.ch/dids/cms/%2FPrimary%2FProcessed%2FTIER/dids"
	_, _, urls, _ := ProcessLogic(query, []mongo.DASRecord{dmap}, nil)
	if _, ok := urls[want]; !ok || len(urls) != 1 {
		t.Fatalf("block4dataset URLs = %v, want only %q", urls, want)
	}
}
