export AWS_PAGER=""

#!/bin/bash
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
STACK_NAME="redshift-test-stack"
TEMPLATE_FILE="redshift-cluster.yaml"
REGION="us-east-2"

# Parámetros opcionales
AUTO_IMPORT=${AUTO_IMPORT:-true}
SKIP_TF_INIT=${SKIP_TF_INIT:-false}

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Deploy Completo: CloudFormation + TF     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Configuración:"
echo "  Stack Name: $STACK_NAME"
echo "  Region: $REGION"
echo "  Template: $TEMPLATE_FILE"
echo ""

# Función para mostrar progreso
show_progress() {
    local message=$1
    echo -e "${YELLOW}▶ $message${NC}"
}

# Función para mostrar éxito
show_success() {
    local message=$1
    echo -e "${GREEN}✓ $message${NC}"
}

# Función para mostrar error
show_error() {
    local message=$1
    echo -e "${RED}✗ $message${NC}"
}

# Función para verificar si el stack ya existe
check_stack_exists() {
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "DOES_NOT_EXIST"
}

# ============================================
# PASO 1: Verificar stack existente
# ============================================
show_progress "Paso 1/5: Verificando stack existente..."

STACK_STATUS=$(check_stack_exists)

if [ "$STACK_STATUS" != "DOES_NOT_EXIST" ]; then
    echo -e "${YELLOW}⚠ El stack '$STACK_NAME' ya existe con estado: $STACK_STATUS${NC}"
    
    if [[ "$STACK_STATUS" == *"COMPLETE"* ]]; then
        echo ""
        read -p "¿Deseas eliminar el stack existente y crear uno nuevo? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            show_progress "Eliminando stack existente..."
            aws cloudformation delete-stack \
                --stack-name "$STACK_NAME" \
                --region "$REGION"
            
            show_progress "Esperando eliminación completa..."
            aws cloudformation wait stack-delete-complete \
                --stack-name "$STACK_NAME" \
                --region "$REGION"
            
            show_success "Stack eliminado"
        else
            show_error "Deploy cancelado por el usuario"
            exit 0
        fi
    else
        show_error "El stack está en un estado no válido. Elimínalo manualmente primero."
        exit 1
    fi
fi

# ============================================
# PASO 2: Crear stack de CloudFormation
# ============================================
show_progress "Paso 2/5: Creando stack de CloudFormation..."

aws cloudformation create-stack \
  --stack-name "$STACK_NAME" \
  --template-body file://"$TEMPLATE_FILE" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION" \
  --parameters \
    ParameterKey=ClusterIdentifier,ParameterValue=redshift-test-cluster \
    ParameterKey=MasterUsername,ParameterValue=awsuser \
    ParameterKey=MasterUserPassword,ParameterValue=TestPass123

if [ $? -ne 0 ]; then
    show_error "Fallo al crear el stack"
    exit 1
fi

show_success "Stack creation iniciado"
echo ""

# ============================================
# PASO 3: Esperar a que el stack se complete
# ============================================
show_progress "Paso 3/5: Esperando a que el stack se complete..."
echo "Esto puede tomar varios minutos (aprox. 5-10 min)..."
echo ""

# Mostrar eventos mientras espera
while true; do
    STATUS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "DOES_NOT_EXIST")

    echo "  Estado actual: $STATUS"

    if [ "$STATUS" = "CREATE_COMPLETE" ]; then
        show_success "Stack creado exitosamente"
        break
    elif [[ "$STATUS" == *"FAILED"* ]] || [[ "$STATUS" == *"ROLLBACK"* ]]; then
        show_error "Error durante la creación del stack ($STATUS)"
        aws cloudformation describe-stack-events \
            --stack-name "$STACK_NAME" \
            --region "$REGION" \
            --max-items 5 \
            --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,ResourceStatusReason]' \
            --output table
        exit 1
    fi
    sleep 20
done

echo ""

# Mostrar outputs del stack
show_progress "Outputs del stack CloudFormation:"
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs' \
    --output table

echo ""

# ============================================
# PASO 4: Inicializar Terraform (opcional)
# ============================================
if [ "$SKIP_TF_INIT" = "false" ]; then
    show_progress "Paso 4/5: Inicializando Terraform..."
    
    if [ -d ".terraform" ]; then
        echo "  Terraform ya está inicializado"
    else
        terraform init
        show_success "Terraform inicializado"
    fi
else
    echo -e "${YELLOW}▶ Paso 4/5: Omitiendo terraform init (SKIP_TF_INIT=true)${NC}"
fi

echo ""

# ============================================
# PASO 5: Importar recursos a Terraform
# ============================================
if [ "$AUTO_IMPORT" = "true" ]; then
    show_progress "Paso 5/5: Importando recursos a Terraform..."
    
    if [ -f "./import-from-cloudformation.sh" ]; then
        # Ejecutar script de importación
        ./import-from-cloudformation.sh
        
        if [ $? -eq 0 ]; then
            show_success "Recursos importados a Terraform"
            
            echo ""
            show_progress "Outputs de Terraform:"
            terraform output
        else
            show_error "Fallo al importar recursos a Terraform"
            echo "Puedes intentar manualmente con: ./import-from-cloudformation.sh"
        fi
    else
        show_error "Script import-from-cloudformation.sh no encontrado"
        echo "Ejecuta manualmente el import después"
    fi
else
    echo -e "${YELLOW}▶ Paso 5/5: Omitiendo import automático (AUTO_IMPORT=false)${NC}"
    echo ""
    echo "Para importar los recursos manualmente, ejecuta:"
    echo "  ./import-from-cloudformation.sh"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       ✓ Deploy Completado Exitosamente    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Próximos pasos:"
echo "  1. Verifica los recursos en AWS Console"
echo "  2. Revisa el estado de Terraform: terraform state list"
echo "  3. Si necesitas hacer cambios: terraform plan"
echo ""
echo "Para limpiar todo:"
echo "  ./destroy.sh"