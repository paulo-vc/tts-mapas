# TTS Mapas

Troca de mapas no centro da mesa do Tabletop Simulator, com props e tokens salvos por mapa. Inspirado no OneWorld.

## Instalação
1. Se você colou a versão antiga no script Global, apague esse código (Modding > Scripting > Global) e clique em Save & Play.
2. **Placa de madeira (recomendado):** Objects > Components > Custom > **Tile**. Em Image, escolha o arquivo `assets/tabula.png` deste repositório (aceite subir para a Cloud), deixe **Stretch desmarcado** e clique em Import.
   - Sem textura também funciona: use Objects > Blocks > Square (fica um bloco cor de madeira).
3. Clique direito na placa > Scripting > Scripting Editor, cole `Controle.lua` e clique em Save & Play.
4. A placa se redimensiona sozinha e vira o painel "Controle de Mapas". Se ficar de cabeça para baixo, gire-a 180°.

Para mudar a textura, edite e rode `tools/gerar_tabula.py` (precisa de `pillow` e `numpy`).

## Uso
- **Calibrar área:** clique em "Calibrar área" e mire o mouse num canto da área amarela em até 3s; repita no canto oposto.
- **Adicionar:** nome + link (.jpg/.png, não WebP) e "+ Adicionar mapa".
- **Trocar:** clique no mapa. Botão direito duas vezes apaga.
- **Mesa / Caber / Preencher:** imagem da própria mesa (esticada) ou tile por cima mantendo a proporção.
- **Fixar selec.:** objetos selecionados não trocam junto com o mapa (o próprio painel já é fixo).
- Tudo fica salvo no próprio bloco.

## Ajustes
- `U` no topo do script controla o tamanho dos botões.

## Estado, grade e pastas
- **Salvar estado / Restaurar:** guarda a posição de props e tokens sobre o mapa e volta para ela depois (Restaurar pede 2 cliques). Mapas com estado salvo mostram `*`.
- **Grade:** grade nativa do TTS por mapa, com tamanho, snap e deslocamento para alinhar com o desenho do mapa.
- **Pastas:** digite um nome e clique em "+ Nova pasta"; mapas criados com a pasta aberta entram nela; "Mover atual p/ cá" move o mapa ativo. Botão direito 2x apaga a pasta (os mapas voltam para a raiz).

## Fog of war
- **Fog: ON/OFF** liga o fog no mapa ativo (cada mapa guarda o seu, inclusive o que já foi revelado).
- O fog é um "teto" preto em células acima do mapa: os jogadores veem preto, o mestre vê o mapa normal. **GM vê** mostra o fog também para o mestre.
- **Pincel revelar / Pincel esconder:** liga o pincel; o que estiver sob o mouse é revelado/coberto. Clique de novo para desligar. **Raio -/+** muda o tamanho.
- **Atalhos (recomendado):** Options > Game Keys > "Fog: revelar (segure)" e "Fog: esconder (segure)". Segure a tecla e passe o mouse.
- **Cobrir tudo / Revelar tudo**, e **Célula -/+** para mudar a resolução (refaz a cobertura).
- Olhando a mesa bem de lado dá para espiar por baixo do teto; jogadores devem usar a visão de cima.
