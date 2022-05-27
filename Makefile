ROBOT_ENV=ROBOT_JAVA_ARGS=-Xmx120G
ROBOT=$(ROBOT_ENV) robot
RG_ENV=JAVA_OPTS=-Xmx120G
RG=$(RG_ENV) relation-graph

SCATLAS_KEEPRELATIONS = relations.txt

ORGAN = lung
ORGAN_ONTOLOGY = master/owl/ccf_Lung_classes.owl

organ-ont.owl:
	echo 'Pulling Organ specific ontology to take its terms'
	wget -O $@ https://raw.githubusercontent.com/hubmapconsortium/ccf-validation-tools/$(ORGAN_ONTOLOGY)

organ-seed.txt: organ-ont.owl
	$(ROBOT) query --input $< --query seed_class.sparql $@.tmp.txt
	cat $@.tmp.txt $(SCATLAS_KEEPRELATIONS) | sed '/term/d' >$@ && rm $@.tmp.txt

organ-annotations.owl: organ-ont.owl organ-seed.txt
	$(ROBOT) filter --input organ-ont.owl --term-file organ-seed.txt --select "self annotations" --output $@

uberon-base.owl:
	wget -O $@ http://purl.obolibrary.org/obo/uberon/uberon-base.owl

cl-base.owl:
	wget -O $@ http://purl.obolibrary.org/obo/cl/cl-base.owl

ro.owl: $(SCATLAS_KEEPRELATIONS)
	wget -O $@.tmp.owl http://purl.obolibrary.org/obo/ro/ro.owl
	$(ROBOT) reason -i $@.tmp.owl --reasoner ELK \
	 extract -T $< --force true --copy-ontology-annotations true --individuals include --method BOT \
	 --output $@_import.tmp.owl && mv $@_import.tmp.owl $@ && rm $@.tmp.owl

merged_imports.owl: uberon-base.owl cl-base.owl ro.owl
	$(ROBOT) merge -i uberon-base.owl -i cl-base.owl -i ro.owl -o $@

materialize-direct.nt: merged_imports.owl $(SCATLAS_KEEPRELATIONS)
	$(RG) --ontology-file $< --properties-file $(SCATLAS_KEEPRELATIONS) --output-file $@

term.facts: organ-seed.txt
	cp $< $@.tmp.facts
	sed -e 's/^/</' -e 's/$\\r/>/' -e 's/$$/>/' -e 's/>>/>/' <$@.tmp.facts >$@ && rm $@.tmp.facts

.PHONY: term.facts

rdf.facts: materialize-direct.nt
	sed 's/ /\t/' <$< | sed 's/ /\t/' | sed 's/ \.$$//' >$@

.PHONY: rdf.facts

ontrdf.facts: merged_imports.owl
	riot --output=ntriples $< | sed 's/ /\t/' | sed 's/ /\t/' | sed 's/ \.$$//' >$@

.PHONY: ontrdf.facts

nonredundant.facts ccf-extended.nt: term.facts rdf.facts ontrdf.facts prune.dl
	souffle -c prune.dl
	cp nonredundant.csv nonredundant.facts
	mv nonredundant.csv ccf-extended.nt

complete-transitive.ofn: term.facts nonredundant.facts ontrdf.facts convert_owl.dl
	souffle -c convert_owl.dl
	sed -e '1s/^/Ontology(<http:\/\/purl.obolibrary.org\/obo\/$(ORGAN)-extended.owl>\n/' -e '$$s/$$/)/' <ofn.csv >$@ && rm ofn.csv

.PHONY: complete-transitive.ofn

organ-extended.owl: complete-transitive.ofn organ-annotations.owl
	$(ROBOT) merge --input organ-annotations.owl --input complete-transitive.ofn \
					 remove --term $(SCATLAS_KEEPRELATIONS) --select complement --select object-properties --trim true -o $@

.PHONY: organ-extended.owl

organ-extended.png: organ-extended.owl ubergraph-style.json
	$(ROBOT) convert --input $< --output $<.json
	og2dot.js -s ubergraph-style.json $<.json > $<.dot 
	dot $<.dot -Tpng -Grankdir=LR > $@
	dot $<.dot -Tpdf -Grankdir=LR > $@.pdf

.PHONY: organ-extended.png