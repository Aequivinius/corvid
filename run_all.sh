#!/bin/bash

home=$(pwd)

echo '0: Creating directories'
mkdir data data/pmids/ data/oger/ data/biobert/ data/harmonised_conll/

echo '1: Downloading PMIDs'
python -c 'import covid; covid.get_pmids()'

cd home/oger
for value in CL
do
echo '2: Running OGER for' $value
oger run -s config/common.ini config/$value.ini -o ../data/oger/$value.conll
collection=$(ls -t ../data/oger/$value/*.conll | head -n1)
cp $collection ../data/oger/$value.conll
done

cd home/bert
echo '3: Preprocessing for BB'
python3 biobert_predict.py \
--do_preprocess=true \
--input_text=../data/oger_collection/CL/collection_2020-04-02_140110.conll \
--tf_record=../data/biobert_collection_tokens/collection.tf_record \
--vocab_file=common/vocab.txt

declare -A vocabularies=( [CHEBI]=52715 [CL]=52714 [GO_BP]=52715 [GO_CC]=52712 [GO_MF]=52710 [MOP]=52710 [NCBITaxon]=52710 [PR]=52720 [SO]=52714 [UBERON]=52717 )

for v in "${!vocabularies[@]}"
do

for s in ids spans
do

echo '3: BB for' $v-$s
mkdir ../data/biobert/$v-$s

mkdir ../data/biobert/$v-$s

python3 biobert_predict.py \
	--do_predict=true \
	--tf_record=../data/biobert_tokens.tf_record \
	--bert_config_file=common/bert_config.json \
	--init_checkpoint=models/$v-$s/model.ckpt-${vocabularies[${v}]} \
	--data_dir=models/$v-$s \
	--output_dir=../data/biobert/$v-$s \
	--configuration=$s

done
done 

cd home
unset vocabularies
declare -A vocabularies=( [CHEBI]=spans-first [CL]=spans-first [GO_BP]=spans-first [GO_CC]=spans-first [GO_MF]=spans-first [MOP]=spans-first [NCBITaxon]=ids-first [PR]=spans-only [SO]=spans-first [UBERON]=spans-first )

for v in "${!vocabularies[@]}"
do
echo '4: Harmonising' $v
python harmonise.py -t data/harmonised_conll/$v.conll -o data/oger/$v.conll -b data/biobert_tokens/collection.tokens -i data/biobert/$v-ids.labels -s data/biobert/$v-spans.labels -m ${vocabularies[$v]}

echo '5: Splitting and .tgz-ing'
python -c 'import covid; covid.conll_collection_to_jsons()'
for v in CHEBI CL GO_BP GO_CC GO_MF MOP NCBITaxon PR SO UBERON
do
tar -czvf data/harmonised_json/$v.tgz data/harmonised_json/$v/
done